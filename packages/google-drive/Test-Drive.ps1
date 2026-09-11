#requires -Version 5.1
param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
try {
    $cfg=Read-DriveConfig $ConfigPath
    $client=@(Get-Process GoogleDriveFS -ErrorAction SilentlyContinue).Count -gt 0
    [pscustomobject]@{
        configuration='valid_locally'
        drive_process_detected=$client
        cloud_sync='not_verified'
        cloud_permissions='not_verified'
        next_step='Export a harmless packet, verify it in Drive on the web or a second device, then import there. Local file presence is not proof of sync.'
    }
} catch {Write-Error 'Configuration or exchange is missing, mismatched or incomplete. Inspect the configured folders without resetting them.';exit 1}
