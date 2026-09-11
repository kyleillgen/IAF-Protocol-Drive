#requires -Version 5.1
param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string[]]$Files,[switch]$ApproveShare)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
if(!$ApproveShare){throw 'Inspect the selected files and use -ApproveShare to copy them into the Drive-managed exchange.'}
$cfg=Read-DriveConfig $ConfigPath
if($Files.Count -lt 1 -or $Files.Count -gt $script:MaxFiles){throw 'Select between 1 and 100 files explicitly; folder recursion is not supported.'}
$seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach($file in $Files){$null=Get-AllowedRelativePath $file;if(!$seen.Add($file)){throw 'Duplicate selected path.'};$null=Join-Safe $cfg.workspace $file}
$lock=Lock-Local $cfg
try {
    $id='packet-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $stage=Join-Safe $cfg.local_state ('outgoing/'+$id)
    if(Test-Path -LiteralPath $stage){throw 'Packet ID already exists.'}
    $null=New-Item -ItemType Directory -Path $stage
    $entries=New-Object 'Collections.Generic.List[object]';$total=0
    foreach($relative in $Files){
        $source=Join-Safe $cfg.workspace $relative
        $bytes=Read-LimitedBytes $source $script:MaxFileBytes
        $total+=$bytes.Length;if($total -gt $script:MaxPacketBytes){throw 'Packet exceeds 20 MiB.'}
        $target=Join-Safe $stage ('files/'+$relative)
        $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        [IO.File]::WriteAllBytes($target,$bytes)
        $entries.Add(@{path=$relative;bytes=$bytes.Length;sha256=(Get-Hash (Read-LimitedBytes $target $script:MaxFileBytes))})
    }
    $manifest=@{schema='agentos-drive-packet-v1';id=$id;base_version='0.2.1';created_utc=[DateTime]::UtcNow.ToString('o');files=@($entries.ToArray())}|ConvertTo-Json -Depth 6
    Write-Utf8 (Join-Path $stage 'manifest.json') $manifest
    $destination=Join-Safe $cfg.share_root ('packets/'+$id)
    if(Test-Path -LiteralPath $destination){throw 'Existing packet preserved.'}
    $null=New-Item -ItemType Directory -Path $destination
    foreach($entry in $entries){
        $target=Join-Safe $destination ('files/'+$entry.path)
        $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        [IO.File]::Copy((Join-Safe $stage ('files/'+$entry.path)),$target,$false)
    }
    # Google may reorder sync. Import always checks every payload, even after this arrives.
    [IO.File]::Copy((Join-Path $stage 'manifest.json'),(Join-Path $destination 'manifest.json'),$false)
    [pscustomobject]@{id=$id;state='exported_locally';cloud_delivery='not_verified';files=$entries.Count;bytes=$total}
} finally {$lock.Dispose()}
