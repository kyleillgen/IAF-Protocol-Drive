#requires -Version 5.1
param(
    [Parameter(Mandatory)][string]$Workspace,
    [Parameter(Mandatory)][string]$ShareRoot,
    [Parameter(Mandatory)][string]$LocalState,
    [switch]$ConfirmDriveFolder,
    [switch]$JoinExisting
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
if(!$ConfirmDriveFolder){throw 'Choose a dedicated folder managed by Drive for desktop and use -ConfirmDriveFolder. No folder has been created.'}
$Workspace=Get-LocalPath $Workspace;$ShareRoot=Get-LocalPath $ShareRoot;$LocalState=Get-LocalPath $LocalState
Assert-Separate $Workspace $ShareRoot;Assert-Separate $Workspace $LocalState;Assert-Separate $ShareRoot $LocalState
if(!(Test-Path -LiteralPath (Join-Path $Workspace 'AGENTS.md')) -or ([IO.File]::ReadAllText((Join-Path $Workspace 'VERSION'))).Trim() -ne '0.2.1'){throw 'First create an AgentOS Portable 0.2.1 workspace.'}
if(Test-Path -LiteralPath $LocalState){throw 'Use a new local-state folder; existing configuration is preserved.'}
if(!(Test-Path -LiteralPath (Split-Path $LocalState -Parent) -PathType Container)){throw 'Local-state parent must exist.'}
if($JoinExisting){
    $marker=([Text.UTF8Encoding]::new($false,$true).GetString((Read-LimitedBytes (Join-Safe $ShareRoot 'exchange.json') 65536)))|ConvertFrom-Json
    if($marker.schema -ne 'agentos-drive-exchange-v1' -or $marker.exchange_id -cnotmatch '^[a-f0-9]{32}$' -or !(Test-Path -LiteralPath (Join-Safe $ShareRoot 'packets') -PathType Container)){throw 'Existing exchange is missing or incomplete. Wait for Drive sync; never initialize over it.'}
    $exchange=$marker.exchange_id
} else {
    if(Test-Path -LiteralPath $ShareRoot){throw 'Use a new Drive exchange folder or -JoinExisting for a verified exchange.'}
    if(!(Test-Path -LiteralPath (Split-Path $ShareRoot -Parent) -PathType Container)){throw 'Drive exchange parent must exist.'}
    $exchange=[guid]::NewGuid().ToString('N')
}
# No existing Drive preferences, model settings, tasks or local run ledger are changed.
$null=New-Item -ItemType Directory -Path $LocalState -ErrorAction Stop
$null=New-Item -ItemType Directory -Path (Join-Path $LocalState 'incoming'),(Join-Path $LocalState 'outgoing')
if(!$JoinExisting){
    $null=New-Item -ItemType Directory -Path $ShareRoot -ErrorAction Stop
    $null=New-Item -ItemType Directory -Path (Join-Path $ShareRoot 'packets')
    Write-Utf8 (Join-Path $ShareRoot 'exchange.json') (@{schema='agentos-drive-exchange-v1';exchange_id=$exchange}|ConvertTo-Json)
    Write-Utf8 (Join-Path $ShareRoot 'README.txt') 'AgentOS file exchange. Packet manifests are readiness hints, not authorization or proof of delivery. Never put credentials or live runtime folders here. Do not edit an existing packet; use a new ID.'
}
Write-Utf8 (Join-Path $LocalState 'drive.json') (@{schema=1;base_version='0.2.1';host=$env:COMPUTERNAME;workspace=$Workspace;share_root=$ShareRoot;local_state=$LocalState;exchange_id=$exchange}|ConvertTo-Json)
Write-Output "Configured locally. Config: $LocalState\drive.json. Google upload/remote visibility: NOT TESTED."
