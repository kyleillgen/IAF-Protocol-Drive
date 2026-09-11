#requires -Version 5.1
$ErrorActionPreference='Stop'
$module=Split-Path $PSScriptRoot -Parent
. "$module/common.ps1"
$root=Join-Path $env:TEMP ('agentos-drive-test-'+[guid]::NewGuid().ToString('N'))
$workspace=Join-Path $root 'workspace';$workspace2=Join-Path $root 'workspace two';$share=Join-Path $root 'simulated drive';$state=Join-Path $root 'local state';$state2=Join-Path $root 'local two'
$null=New-Item -ItemType Directory -Path $workspace,$workspace2 -Force
foreach($w in @($workspace,$workspace2)){Write-Utf8 (Join-Path $w 'AGENTS.md') '# synthetic fixture';Write-Utf8 (Join-Path $w 'VERSION') '0.2.1'}
$null=New-Item -ItemType Directory -Path "$workspace/tasks/hello"
$greeting='Hello '+[char]0x03bb+[char]0x4e2d
Write-Utf8 "$workspace/tasks/hello/task.md" $greeting
& "$module/Initialize-Drive.ps1" -Workspace $workspace -ShareRoot $share -LocalState $state -ConfirmDriveFolder
& "$module/Initialize-Drive.ps1" -Workspace $workspace2 -ShareRoot $share -LocalState $state2 -ConfirmDriveFolder -JoinExisting
$config=Join-Path $state 'drive.json';$config2=Join-Path $state2 'drive.json'
$before=Get-Hash (Read-LimitedBytes $config 65536)
function Must-Fail([scriptblock]$Action,[string]$Label){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};if(!$failed){throw "Expected rejection: $Label"}}
Must-Fail {& "$module/Initialize-Drive.ps1" -Workspace $workspace -ShareRoot $share -LocalState $state -ConfirmDriveFolder} 'existing setup'
if((Get-Hash (Read-LimitedBytes $config 65536)) -ne $before){throw 'Existing configuration changed'}
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/hello/task.md'} 'missing approval'
$packet=& "$module/Export-Packet.ps1" -ConfigPath $config -Files @('tasks/hello/task.md','AGENTS.md') -ApproveShare
$import=& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $packet.id
if([IO.File]::ReadAllText((Join-Path $import.location 'files/tasks/hello/task.md')) -cne $greeting){throw 'Unicode round-trip failed'}
Must-Fail {& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $packet.id} 'duplicate import'
if(Test-Path -LiteralPath "$workspace2/work"){throw 'Import touched runtime queue'}
foreach($bad in @('../escape.md','C:/escape.md','C:escape.md','/absolute.md','tasks/a/../../evil.md','tasks/a/CON.txt','tasks/a/x.md:stream','tasks/a/x.','tasks/a/x ','tasks//x.md','runners/dispatcher.json','work/status/job.json','tasks/a/auth.json','tasks/a/run.ps1','work/results/job/execute-stdout.txt')) {
    Must-Fail {Get-AllowedRelativePath $bad} $bad
}
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files @('AGENTS.md','agents.md') -ApproveShare} 'case duplicate'
# Simulate manifest arriving before its payload. A later explicit retry must work.
$packet2=& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/hello/task.md' -ApproveShare
$file=Join-Path $share "packets/$($packet2.id)/files/tasks/hello/task.md"
$saved=Read-LimitedBytes $file 65536
Move-Item -LiteralPath $file -Destination ($file+'.test-backup')
Must-Fail {& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $packet2.id} 'manifest before payload'
if(Test-Path -LiteralPath "$state2/incoming/$($packet2.id)"){throw 'Incomplete packet finalized'}
[IO.File]::WriteAllBytes($file,$saved)
$null=& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $packet2.id
$packet3=& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/hello/task.md' -ApproveShare
Write-Utf8 (Join-Path $share "packets/$($packet3.id)/files/tasks/hello/task.md") 'corrupt'
Must-Fail {& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $packet3.id} 'corrupt payload'
if(Test-Path -LiteralPath "$state2/incoming/$($packet3.id)"){throw 'Corrupt packet finalized'}
# Malicious manifests are rejected before finalization.
foreach($kind in @('traversal','duplicate','false-size','oversize-manifest','forbidden')){
    $p=& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/hello/task.md' -ApproveShare
    $manifestPath=Join-Path $share "packets/$($p.id)/manifest.json"
    $m=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    switch($kind){
        traversal {$m.files[0].path='../outside.md'}
        duplicate {$m.files=@($m.files[0],$m.files[0])}
        false-size {$m.files[0].bytes=0}
        forbidden {$m.files[0].path='work/results/job/review-runtime.json'}
    }
    if($kind -eq 'oversize-manifest'){Write-Utf8 $manifestPath ('x'*131073)}else{Write-Utf8 $manifestPath ($m|ConvertTo-Json -Depth 6)}
    Must-Fail {& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $p.id} $kind
    if(Test-Path -LiteralPath "$state2/incoming/$($p.id)"){throw 'Invalid manifest finalized'}
}
# Actual byte limits apply even if a manifest lies about size.
$large=Join-Path $workspace 'tasks/hello/large.txt'
[IO.File]::WriteAllBytes($large,(New-Object byte[] 10485761))
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/hello/large.txt' -ApproveShare} 'oversize file'
Must-Fail {& "$module/Initialize-Drive.ps1" -Workspace $workspace -ShareRoot "$workspace/nested" -LocalState "$root/other" -ConfirmDriveFolder} 'overlap'# Aggregate and count limits cannot be bypassed by individually valid file sizes.
$many=@(1..101|ForEach-Object {'tasks/hello/file'+$_+'.txt'})
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files $many -ApproveShare} 'too many selected files'
$aggregate=@()
foreach($n in 1..3){$relative='tasks/hello/part'+$n+'.txt';$aggregate+=$relative;[IO.File]::WriteAllBytes((Join-Path $workspace $relative),(New-Object byte[] 7340032))}
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files $aggregate -ApproveShare} 'aggregate bytes'
$p=& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'AGENTS.md' -ApproveShare
$manifestPath=Join-Path $share "packets/$($p.id)/manifest.json"
$m=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$m.files=@(1..101|ForEach-Object {@{path=('tasks/hello/file'+$_+'.txt');bytes=0;sha256=('0'*64)}})
Write-Utf8 $manifestPath ($m|ConvertTo-Json -Depth 6)
Must-Fail {& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $p.id} 'too many manifest entries'
# Unicode file names and spaces are retained exactly.
$relative='tasks/hello/note '+[char]0x03bb+'.txt'
Write-Utf8 (Join-Path $workspace $relative) $greeting
$p=& "$module/Export-Packet.ps1" -ConfigPath $config -Files $relative -ApproveShare
$i=& "$module/Import-Packet.ps1" -ConfigPath $config2 -PacketId $p.id
if([IO.File]::ReadAllText((Join-Path $i.location ('files/'+$relative))) -cne $greeting){throw 'Unicode file name round-trip failed'}
# Reparse points are never followed, even within an otherwise allowed task prefix.
$outside=Join-Path $root 'outside';$null=New-Item -ItemType Directory -Path $outside
Write-Utf8 (Join-Path $outside 'note.txt') 'do not export'
$junction=Join-Path $workspace 'tasks/junction'
$null=New-Item -ItemType Junction -Path $junction -Target $outside
Must-Fail {& "$module/Export-Packet.ps1" -ConfigPath $config -Files 'tasks/junction/note.txt' -ApproveShare} 'junction'
# Untrusted shared metadata is bounded, not read with an unbounded ReadAllText.
$markerPath=Join-Path $share 'exchange.json';$marker=Read-LimitedBytes $markerPath 65536
Write-Utf8 $markerPath ('x'*65537)
Must-Fail {Read-DriveConfig $config} 'oversize exchange marker'
[IO.File]::WriteAllBytes($markerPath,$marker)
& "$module/Test-Drive.ps1" -ConfigPath $config
'PASS: local simulated Drive exchange, Unicode, two-workspace handoff, duplicate preservation, explicit approval, unsafe paths, forbidden records, delayed/corrupt sync and size limits. No Google/cloud access was tested.'
