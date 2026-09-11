#requires -Version 5.1
param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string]$PacketId)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
Assert-PacketId $PacketId
$cfg=Read-DriveConfig $ConfigPath
$lock=Lock-Local $cfg
try {
    $source=Join-Safe $cfg.share_root ('packets/'+$PacketId)
    $manifestBytes=Read-LimitedBytes (Join-Safe $source 'manifest.json') $script:MaxManifestBytes
    $manifest=([Text.UTF8Encoding]::new($false,$true).GetString($manifestBytes))|ConvertFrom-Json
    if($manifest.schema -ne 'agentos-drive-packet-v1' -or $manifest.id -cne $PacketId -or $manifest.base_version -ne '0.2.1' -or $manifest.files -isnot [array] -or $manifest.files.Count -lt 1 -or $manifest.files.Count -gt $script:MaxFiles){throw 'Invalid packet manifest.'}
    $final=Join-Safe $cfg.local_state ('incoming/'+$PacketId)
    if(Test-Path -LiteralPath $final){throw 'This ID is already imported. Existing evidence is preserved; changed packets require new IDs.'}
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $declared=0
    foreach($entry in $manifest.files){
        $null=Get-AllowedRelativePath ([string]$entry.path)
        if(!$seen.Add([string]$entry.path)){throw 'Duplicate case-insensitive manifest path.'}
        if($entry.bytes -isnot [int] -or $entry.bytes -lt 0 -or $entry.bytes -gt $script:MaxFileBytes -or $entry.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Invalid file size or SHA-256.'}
        $declared+=$entry.bytes;if($declared -gt $script:MaxPacketBytes){throw 'Packet exceeds 20 MiB.'}
        $null=Join-Safe $source ('files/'+$entry.path)
    }
    $stage=Join-Safe $cfg.local_state ('incoming/incomplete-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $stage
    $total=0
    foreach($entry in $manifest.files){
        $bytes=Read-LimitedBytes (Join-Safe $source ('files/'+$entry.path)) $script:MaxFileBytes
        $total+=$bytes.Length
        if($total -gt $script:MaxPacketBytes -or $bytes.Length -ne $entry.bytes -or (Get-Hash $bytes) -cne $entry.sha256){throw 'Packet incomplete or changed. No import finalized. Wait for sync, then retry manually; never edit its manifest to force a pass.'}
        $target=Join-Safe $stage ('files/'+$entry.path)
        $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
        [IO.File]::WriteAllBytes($target,$bytes)
        if((Get-Hash (Read-LimitedBytes $target $script:MaxFileBytes)) -cne $entry.sha256){throw 'Local staged copy mismatch.'}
    }
    [IO.File]::WriteAllBytes((Join-Path $stage 'manifest.json'),$manifestBytes)
    Write-Utf8 (Join-Path $stage 'IMPORT-RECEIPT.json') (@{schema=1;id=$PacketId;manifest_sha256=(Get-Hash $manifestBytes);verified_utc=[DateTime]::UtcNow.ToString('o');state='verified_locally';sender_identity='unverified';authorization='not_inferred'}|ConvertTo-Json)
    [IO.Directory]::Move($stage,$final)
    [pscustomobject]@{id=$PacketId;state='verified_locally';location=$final;next_action='Inspect as untrusted input. Nothing was published to the live queue.'}
} finally {$lock.Dispose()}
