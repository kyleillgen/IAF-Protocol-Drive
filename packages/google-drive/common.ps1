#requires -Version 5.1
$script:MaxManifestBytes=131072
$script:MaxFileBytes=10485760
$script:MaxPacketBytes=20971520
$script:MaxFiles=100
function Get-LocalPath([string]$Path) {
    if($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path.IndexOfAny([char[]]'[]*?') -ge 0) {throw 'Use an absolute drive path without wildcard characters.'}
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if($full.Length -le 2){throw 'Choose a dedicated folder, not a drive root.'}
    $part=$full
    while($part){
        if(Test-Path -LiteralPath $part){if((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Junctions and symbolic links are not supported.'}}
        $part=Split-Path $part -Parent
    }
    return $full
}
function Assert-Separate([string]$A,[string]$B) {
    if($A.Equals($B,[StringComparison]::OrdinalIgnoreCase) -or $A.StartsWith($B+'\',[StringComparison]::OrdinalIgnoreCase) -or $B.StartsWith($A+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Workspace, Drive exchange and local state must be separate; none may contain another.'}
}
function Assert-PacketId([string]$Id) {
    if($Id -cnotmatch '^[a-z][a-z0-9-]{0,63}$' -or $Id -match '^(con|prn|aux|nul|com[0-9\u00b9\u00b2\u00b3]|lpt[0-9\u00b9\u00b2\u00b3])$'){throw 'Invalid packet ID.'}
}
function Get-AllowedRelativePath([string]$Path) {
    if([string]::IsNullOrWhiteSpace($Path) -or $Path.Length -gt 180 -or $Path.Contains('\') -or $Path.StartsWith('/') -or $Path.Contains(':')){throw 'Use a short relative path with forward slashes.'}
    foreach($part in $Path.Split('/')) {
        if(!$part -or $part -in @('.','..') -or $part.EndsWith('.') -or $part.EndsWith(' ') -or $part.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $part -match '^(con|prn|aux|nul|com[0-9\u00b9\u00b2\u00b3]|lpt[0-9\u00b9\u00b2\u00b3])(\.|$)' -or $part -match '^[.]'){throw 'Unsafe packet path.'}
    }
    if($Path -notmatch '^(AGENTS\.md|CLAUDE\.md|GEMINI\.md|PROTOCOL\.md|TEAM\.md|(?:tasks|knowledge)/.+|work/results/[a-z][a-z0-9-]{0,63}/.+)$'){throw 'Only selected governance, task, knowledge and result files may be shared.'}
    if([IO.Path]::GetExtension($Path) -notin @('.md','.txt','.json','.csv')){throw 'This starter supports Markdown, text, JSON and CSV files only.'}
    if($Path -match '(?i)(^|/)(runners|state|inbox|receipts|handoffs|node_modules|credentials|secrets|auth)(/|\.)|(^|/)(execute|review)\.txt$|(^|/)[^/]*(prompt|stdout|stderr|verdict|runtime|credential|secret|token|config|ledger)[^/]*$'){throw 'Runtime records, credentials and configuration are not shareable through this adapter.'}
    return $Path
}
function Join-Safe([string]$Root,[string]$Relative) {
    $path=Get-LocalPath (Join-Path $Root ($Relative.Replace('/','\')))
    if(!$path.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes its root.'}
    return $path
}
function Read-LimitedBytes([string]$Path,[int]$Limit) {
    $stream=[IO.File]::Open($Path,'Open','Read','Read')
    $memory=New-Object IO.MemoryStream
    try {
        $buffer=New-Object byte[] 65536
        while(($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
            if($memory.Length+$count -gt $Limit){throw 'File exceeds the packet size limit.'}
            $memory.Write($buffer,0,$count)
        }
        return ,$memory.ToArray()
    } finally {$stream.Dispose();$memory.Dispose()}
}
function Get-Hash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Write-Utf8([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Read-DriveConfig([string]$Path) {
    $Path=Get-LocalPath $Path
    $cfg=([Text.UTF8Encoding]::new($false,$true).GetString((Read-LimitedBytes $Path 65536)))|ConvertFrom-Json
    if($cfg.schema -ne 1 -or $cfg.base_version -ne '0.2.1' -or $cfg.host -ne $env:COMPUTERNAME){throw 'Invalid configuration or wrong designated computer.'}
    $cfg.workspace=Get-LocalPath ([string]$cfg.workspace)
    $cfg.share_root=Get-LocalPath ([string]$cfg.share_root)
    $cfg.local_state=Get-LocalPath ([string]$cfg.local_state)
    Assert-Separate $cfg.workspace $cfg.share_root;Assert-Separate $cfg.workspace $cfg.local_state;Assert-Separate $cfg.share_root $cfg.local_state
    if((Split-Path $Path -Parent) -ne $cfg.local_state){throw 'Keep drive.json in its configured local-state directory.'}
    foreach($p in @($cfg.workspace,$cfg.share_root,$cfg.local_state)){if(!(Test-Path -LiteralPath $p -PathType Container)){throw 'A configured folder is unavailable.'}}
    if(([IO.File]::ReadAllText((Join-Path $cfg.workspace 'VERSION'))).Trim() -ne '0.2.1'){throw 'This adapter requires base 0.2.1.'}
    $marker=([Text.UTF8Encoding]::new($false,$true).GetString((Read-LimitedBytes (Join-Safe $cfg.share_root 'exchange.json') 65536)))|ConvertFrom-Json
    if($marker.schema -ne 'agentos-drive-exchange-v1' -or $marker.exchange_id -ne $cfg.exchange_id){throw 'Wrong Drive exchange folder.'}
    return $cfg
}
function Lock-Local($Config){return [IO.File]::Open((Join-Path $Config.local_state 'exchange.lock'),'OpenOrCreate','ReadWrite','None')}
