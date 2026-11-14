[CmdletBinding()]
param(
 [string]$Godot='',
 [ValidateRange(1,3)][int]$Clients=3,
 [ValidateRange(1024,65535)][int]$Port=24600,
 [ValidateRange(500,3600000)][int]$PlayMs=2500,
 [ValidateRange(1000,120000)][int]$TimeoutMs=20000,
 [ValidateRange(15,360)][int]$HostFps=60,
 [ValidateRange(15,360)][int]$GuestFps=240,
 [ValidateSet('All','Host','Guest')][string]$Role='All',
 [ValidateRange(0,2)][int]$Index=0,
 [string]$Address='127.0.0.1',
 [string]$RunId='',
 [string]$Pack='',
 [string]$LogRoot='',
 [switch]$SkipImport,
 [switch]$ReturnResult
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if($Index -ge $Clients){throw 'Index must be lower than Clients.'}
if(-not $RunId){
 if($Role -ne 'All'){throw 'Manual Host/Guest mode requires the same -RunId on both computers.'}
 $RunId=[Guid]::NewGuid().ToString('N')
}
if($RunId -notmatch '^[A-Za-z0-9_-]{1,80}$'){throw 'RunId must contain 1-80 letters, digits, underscores or hyphens.'}
function Find-Engine {
 if($Godot){return (Resolve-Path -LiteralPath $Godot).Path}
 if($env:GODOT){return (Resolve-Path -LiteralPath $env:GODOT).Path}
 $sibling=Join-Path $project '../Godot_v4.7.2-stable_win64_console.exe'
 if(Test-Path -LiteralPath $sibling){return (Resolve-Path -LiteralPath $sibling).Path}
 foreach($name in @('godot','godot4')){$command=Get-Command $name -ErrorAction SilentlyContinue;if($command){return $command.Source}}
 throw 'Godot not found. Pass -Godot with the engine path (or the exported EXE with -Pack).'
}
$engine=Find-Engine
if([IO.Path]::GetFileName($engine) -match "^Mystical Garden v"){throw "Use the Godot engine for -Godot and the game EXE for -Pack. Shipping builds disable command-line path overrides."}
if($Pack){$Pack=(Resolve-Path -LiteralPath $Pack).Path}
if(-not $LogRoot){$LogRoot=Join-Path $project '.godot/network-tests'}
$profileRoot=$null
if($env:MYSTICAL_VALIDATION_SMOKE_PROFILES){
 $profileRoot=[IO.Path]::GetFullPath($env:MYSTICAL_VALIDATION_SMOKE_PROFILES)
 $projectParent=[IO.Path]::GetDirectoryName($project)
 if($profileRoot -cne (Join-Path $projectParent 'n') -or -not (Test-Path -LiteralPath $profileRoot -PathType Container)){
  throw 'Smoke profile root must be the owned disposable workspace n directory.'
 }
 for($part=$profileRoot;$part;$part=Split-Path -Parent $part){
  if((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Smoke profile cannot cross a reparse point.'}
 }
}
$runPath=Join-Path $LogRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $runPath | Out-Null
$runPath=(Resolve-Path -LiteralPath $runPath).Path
$profilePath=$runPath
if($profileRoot){
 $profilePath=Join-Path $profileRoot (Split-Path -Leaf $runPath)
 New-Item -ItemType Directory -Path $profilePath | Out-Null
}
foreach($folder in @('saves','userdata','localdata','temp')){New-Item -ItemType Directory -Force -Path (Join-Path $profilePath $folder) | Out-Null}
$environmentBefore=@{}
foreach($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP','XDG_DATA_HOME','MYSTICAL_GARDEN_TEST_PORT','MYSTICAL_VALIDATION_RUN')){$environmentBefore[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
$peers=@();$rows=@();$setupError='';$summary=$null
function Quote-Argument([string]$value){
 if($value.Contains('"')){throw 'Quote characters are not allowed in process arguments.'}
 return '"'+$value+'"'
}
function Start-Peer([string]$PeerRole,[int]$PeerIndex){
 $name="$PeerRole-$PeerIndex"; $stdout=Join-Path $runPath "$name.stdout.log"; $stderr=Join-Path $runPath "$name.stderr.log"
 $runtimePath=if($Pack){$runPath}else{$project}
 $arguments=@('--headless','--path',(Quote-Argument $runtimePath),'--script',(Quote-Argument $driver),'--log-file',(Quote-Argument (Join-Path $runPath "$name.engine.log")),'--max-fps',([string]$(if($PeerRole -eq 'host'){$HostFps}else{$GuestFps})))
 if($Pack){$arguments+=@('--main-pack',(Quote-Argument $Pack))}
 $arguments+=@('--','--role',$PeerRole,'--index',"$PeerIndex",'--guests',"$Clients",'--port',"$Port",'--address',(Quote-Argument $Address),'--run-id',$RunId,'--play-ms',"$PlayMs",'--timeout-ms',"$TimeoutMs",'--save-root',(Quote-Argument 'user://release-fixtures/supplied-network'),'--report-dir',(Quote-Argument $runPath),'--packaged',$(if($Pack){'true'}else{'false'}))
 $options=@{FilePath=$engine;ArgumentList=$arguments;PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($env:OS -eq 'Windows_NT'){$options.WindowStyle='Hidden'}
 $process=Start-Process @options
 return @{name=$name;role=$PeerRole;index=$PeerIndex;process=$process;stdout=$stdout;stderr=$stderr;result=(Join-Path $runPath "result_$($PeerRole)_$PeerIndex.json");timed_out=$false}
}
try {
 $env:APPDATA=Join-Path $profilePath 'userdata';$env:LOCALAPPDATA=Join-Path $profilePath 'localdata';$env:TEMP=Join-Path $profilePath 'temp';$env:TMP=$env:TEMP;$env:XDG_DATA_HOME=$env:APPDATA;$env:MYSTICAL_GARDEN_TEST_PORT=[string]$Port;$env:MYSTICAL_VALIDATION_RUN=$RunId
 if($Pack){
  $lockResource='assets/native/persistence_lock/b0_native_lock.dll'
  $sourceLock=Join-Path $project $lockResource
  if(Test-Path -LiteralPath $sourceLock -PathType Leaf){
   $packLock=Join-Path (Split-Path -Parent $Pack) 'b0_native_lock.dll'
   if(-not (Test-Path -LiteralPath $packLock -PathType Leaf) -or (Get-FileHash -LiteralPath $packLock).Hash -ne (Get-FileHash -LiteralPath $sourceLock).Hash){throw 'Missing or mismatched packaged persistence lock.'}
   $runtimeLock=Join-Path $runPath $lockResource
   New-Item -ItemType Directory -Force -Path (Split-Path -Parent $runtimeLock) | Out-Null
   Copy-Item -LiteralPath $packLock -Destination $runtimeLock
  }
 }
 Write-Host "Network smoke: $Role, $Clients guests, UDP $Port, host ${HostFps}fps / guests ${GuestFps}fps"
 Write-Host "Run ID: $RunId"
 Write-Host "Reports: $runPath"
 if(-not $Pack -and -not $SkipImport){
  & $engine --headless --path $project --editor --import --quit --log-file (Join-Path $runPath 'import.engine.log') *> (Join-Path $runPath 'import.log')
  if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $runPath 'import.log') -Pattern 'SCRIPT ERROR|Parse Error|^\s*(?:USER )?ERROR:' -Quiet)){throw 'Project import failed; see import.log.'}
 }
 $harness=(Join-Path $PSScriptRoot 'net_test.gd').Replace('\','/')
 $driver=Join-Path $runPath 'driver.gd'
 $source=@"
extends SceneTree
func _initialize():
 var script=load("$harness")
 if script==null: quit(3);return
 var harness=script.new();harness.name="NetTest";root.add_child(harness)
"@
 # GDScript receives literal quotes, never shell-expanded source.
 [IO.File]::WriteAllText($driver,$source,[Text.UTF8Encoding]::new($false))
 if($Role -ne 'Guest'){
  $peers+=Start-Peer 'host' 0
  $ready=Join-Path $runPath 'host.ready.json';$readyUntil=[DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
  while(-not (Test-Path -LiteralPath $ready) -and -not $peers[0].process.HasExited -and [DateTime]::UtcNow -lt $readyUntil){Start-Sleep -Milliseconds 75}
  if(-not (Test-Path -LiteralPath $ready)){throw 'Host did not bind successfully; see host-0 logs.'}
 }
 if($Role -eq 'All'){for($i=0;$i -lt $Clients;$i++){$peers+=Start-Peer 'guest' $i}}
 elseif($Role -eq 'Guest'){$peers+=Start-Peer 'guest' $Index}
 $deadline=[DateTime]::UtcNow.AddMilliseconds($PlayMs+5*$TimeoutMs+10000)
 while(@($peers | Where-Object {-not $_.process.HasExited}).Count -gt 0 -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
 foreach($peer in $peers){if(-not $peer.process.HasExited){$peer.timed_out=$true;$peer.process.Kill();$peer.process.WaitForExit()}}
} catch {
 $setupError=$_.Exception.Message
 Write-Host "SETUP FAIL: $setupError"
} finally {
 foreach($peer in $peers){if(-not $peer.process.HasExited){$peer.timed_out=$true;$peer.process.Kill();$peer.process.WaitForExit()}}
 foreach($key in $environmentBefore.Keys){[Environment]::SetEnvironmentVariable($key,$environmentBefore[$key],'Process')}
}
foreach($peer in $peers){
 $peer.process.WaitForExit();$peer.process.Refresh();$code=$peer.process.ExitCode
 $report=$null
 if(Test-Path -LiteralPath $peer.result){try{$report=Get-Content -LiteralPath $peer.result -Raw | ConvertFrom-Json}catch{}}
 $scriptError=$false
 foreach($path in @($peer.stdout,$peer.stderr,(Join-Path $runPath "$($peer.name).engine.log"))){
  if(Test-Path -LiteralPath $path){$scriptError=$scriptError -or (Select-String -LiteralPath $path -Pattern 'SCRIPT ERROR|Parse Error|^\s*(?:USER )?ERROR:' -Quiet)}else{$scriptError=$true}
 }
 $marker=(Test-Path -LiteralPath $peer.stdout) -and (Select-String -LiteralPath $peer.stdout -Pattern 'RESULT PASS' -Quiet)
 $passed=-not $peer.timed_out -and $code -eq 0 -and $null -ne $report -and $report.schema -eq 3 -and $report.fixture -ceq "supplied_network_smoke" -and $report.run_id -ceq $RunId -and $report.role -eq $peer.role -and $report.index -eq $peer.index -and $report.status -eq 'PASS' -and $null -ne $report.exit -and $report.exit -eq 0 -and $report.metrics.peer -gt 0 -and $marker -and -not $scriptError
 $rows+=@{name=$peer.name;passed=$passed;exit=$code;timeout=$peer.timed_out;script_error=$scriptError;report=$peer.result;metrics=$(if($report){$report.metrics}else{$null});message=$(if($report){$report.message}else{'Missing or invalid peer result'})}
 Write-Host ("{0}: {1} (exit {2})" -f $peer.name,$(if($passed){'PASS'}else{'FAIL'}),$code)
}
$expected=if($Role -eq 'All'){$Clients+1}else{1}
$passed=-not $setupError -and $rows.Count -eq $expected -and @($rows | Where-Object {-not $_.passed}).Count -eq 0
$summary=@{schema=3;fixture='supplied_network_smoke';passed=$passed;run_id=$RunId;role=$Role;clients=$Clients;port=$Port;pack=$Pack;host_fps=$HostFps;guest_fps=$GuestFps;play_ms=$PlayMs;setup_error=$setupError;reports=$runPath;peers=$rows}
$summary | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 (Join-Path $runPath 'summary.json')
Write-Host $(if($passed){'PASS: network smoke host/guest coordination, movement, animation and private details'}else{'FAIL: network smoke; see summary.json and per-peer logs'})
if($ReturnResult){return $summary}
if($passed){exit 0}else{exit 1}
