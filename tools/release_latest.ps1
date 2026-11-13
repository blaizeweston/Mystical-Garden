param([string]$Engine=(Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe'),[Alias('Target')][string]$TargetPath='', [switch]$Full, [switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:APPDATA=Join-Path $project '.godot/stabilization-appdata'
$env:LOCALAPPDATA=Join-Path $project '.godot/stabilization-localappdata'
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
$build=Join-Path $project '.godot/release'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$env:TEMP=Join-Path $build 'temp'
$env:TMP=$env:TEMP
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
. (Join-Path $PSScriptRoot 'validation_python.ps1')
$python=Find-ValidationPython
& $python (Join-Path $PSScriptRoot 'test_workflow.py') verify --project $project --engine $Engine
if($LASTEXITCODE -ne 0){throw 'Run Connected validation before exporting.'}
$results=Get-Content -LiteralPath (Join-Path $project '.godot/stabilization/release-checks.json') -Raw | ConvertFrom-Json
$planArgs=@((Join-Path $PSScriptRoot 'test_workflow.py'),'package-plan','--project',$project,'--engine',$Engine)
if($Full){$planArgs+='--full-package'}
& $python @planArgs | Out-Null
if($LASTEXITCODE -ne 0){throw 'Could not produce a current packaged test plan.'}
$packagePlan=Get-Content -LiteralPath (Join-Path $project '.godot/validation/package-plan.json') -Raw | ConvertFrom-Json
Write-Output ('Package validation: '+(@($packagePlan.selected.unit).Count+@($packagePlan.selected.pair).Count+@($packagePlan.selected.party).Count+@($packagePlan.selected.smoke).Count)+' selected, '+@($packagePlan.reused).Count+' reusable; startup smoke always runs.')
$packageRun=Join-Path $project ('.godot/validation/package-runs/'+$packagePlan.run_id)
function Invoke-ValidationFixture([string]$Fixture,[string]$Kind,[string]$Script='',[string]$PackPath='',[int]$Port=0) {
 $fixtureArgs=@((Join-Path $PSScriptRoot 'validation_execution.py'),'--project',$project,'--engine',$Engine,
   '--fixture',$Fixture,'--kind',$Kind,'--run-id',$packagePlan.run_id,'--log-root',$packageRun)
 if($Script){$fixtureArgs+=@('--script',$Script)}
 if($PackPath){$fixtureArgs+=@('--pack',$PackPath)}
 if($Port){$fixtureArgs+=@('--port',"$Port")}
 & $python @fixtureArgs
 if($LASTEXITCODE -ne 0){throw "$Fixture validation failed. See $packageRun."}
}
Invoke-ValidationFixture 'catalog_preflight' 'unit' (Join-Path $project 'tests/content_validation.gd')
$targetDirectory=$project
if($TargetPath){
 $selected=Get-Item -LiteralPath $TargetPath
 if($selected.PSIsContainer -or $selected.BaseName -notmatch '^Mystical Garden v(\d+(?:\.\d+){1,3})$'){throw 'Target must be an existing numbered Mystical Garden EXE.'}
 $targetDirectory=$selected.DirectoryName
}
function Latest {
 @(Get-ChildItem -LiteralPath $targetDirectory -File -Filter '*.exe' | Where-Object {$_.BaseName -match '^Mystical Garden v(\d+(?:\.\d+){1,3})$'} | Sort-Object @{Expression={[version]($_.BaseName -replace '^Mystical Garden v','')};Descending=$true})[0]
}
$target=Latest
if($TargetPath -and $target.FullName -ne $selected.FullName){throw 'A higher revision exists beside the selected target. Select the highest revision.'}
if($null -eq $target){throw 'No numbered release EXE found. Refusing to invent a milestone.'}
$fingerprint=& (Join-Path $PSScriptRoot 'runtime_fingerprint.ps1') -Project $project
$stamp=Join-Path $project '.godot/stabilization/validated-source.sha256'
if(-not (Test-Path -LiteralPath $stamp) -or (Get-Content -LiteralPath $stamp -Raw).Trim() -ne $fingerprint){throw 'Runtime source changed since validation. Run validate_release.ps1 again.'}
@{schema=2;milestone=$target.BaseName;built_utc=[DateTime]::UtcNow.ToString('o');source_fingerprint=$fingerprint;engine='4.7.2';checks=$results.Count} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $project 'assets/content/build_manifest.json')
$templates=Join-Path $env:USERPROFILE 'AppData/Roaming/Godot/export_templates/4.7.2.stable'
$preset=Join-Path $project 'export_presets.cfg'
$text=Get-Content -LiteralPath $preset -Raw
$text=[regex]::Replace($text,'export_path="[^"]+"',('export_path="./'+$target.Name+'"'))
foreach($mode in @('debug','release')) {
 $template=(Join-Path $templates ('windows_'+$mode+'_x86_64.exe')).Replace('\','/')
 if(-not (Test-Path -LiteralPath $template)){throw ('Missing export template: '+$template)}
 $text=[regex]::Replace($text,('custom_template/'+$mode+'="[^"]*"'),('custom_template/'+$mode+'="'+$template+'"'))
}
[IO.File]::WriteAllText($preset,$text,[Text.UTF8Encoding]::new($false))
$stageDirectory=Join-Path $build ([Guid]::NewGuid().ToString('N').Substring(0,12))
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$staged=Join-Path $stageDirectory ('Mystical Garden-staged.exe')
$sourceLock=Join-Path $project 'assets/native/persistence_lock/b0_native_lock.dll'
$stagedLock=Join-Path $stageDirectory 'b0_native_lock.dll'
$installedLock=Join-Path $targetDirectory 'b0_native_lock.dll'
$log=Join-Path $build 'export.log'
& $Engine --headless --path $project --export-release 'Windows Desktop' $staged *> $log
if($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $staged)){throw 'Export failed; current EXE remains intact.'}
if(-not (Test-Path -LiteralPath $stagedLock -PathType Leaf) -or (Get-FileHash -LiteralPath $stagedLock).Hash -ne (Get-FileHash -LiteralPath $sourceLock).Hash){throw 'Missing or mismatched exported persistence lock.'}
$verifiedLockHash=(Get-FileHash -LiteralPath $stagedLock).Hash
if(Select-String -LiteralPath $log -Pattern 'res://(?:docs|tests|tools|assets/source)/' -Quiet){throw 'Export included excluded source or archives.'}
$smoke=Join-Path $packageRun 'package_smoke.gd'
@'
extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var errors: Array=load("res://content_validator.gd").validate()
 for error in errors: printerr(error)
 for forbidden in ["res://test/net_test.gd","res://test/net_test.tscn","res://tests/playable.gd","res://tools/make_natural_world.py","res://docs/SYSTEMS_REVIEW_2026-11-08.md","res://assets/source/natural_world.blend"]:
  if FileAccess.file_exists(forbidden): errors.append("Excluded resource present: "+forbidden);printerr("Excluded resource present: "+forbidden)
 var world=load("res://world.tscn").instantiate()
 world.progress.path="user://garden.cfg";world.local_character.path="user://character.cfg";root.add_child(world)
 world.map_seed=91247;world.reset_encounter();world._process(.016)
 world.queue_free();await process_frame
 if errors.is_empty(): print("PASS: packaged runtime catalogs, world and exclusions")
 quit(0 if errors.is_empty() else 1)
'@ | Set-Content -Encoding utf8 $smoke
Invoke-ValidationFixture 'package_startup' 'unit' $smoke $staged
foreach($testName in @($packagePlan.selected.unit)) {
 Invoke-ValidationFixture $testName 'unit' -PackPath $staged
}
foreach($testName in @($packagePlan.selected.pair)) {
 Invoke-ValidationFixture $testName 'pair' -PackPath $staged -Port 32291
}
if(@($packagePlan.selected.party).Count){
 & (Join-Path $PSScriptRoot 'test_four_players.ps1') -Engine $Engine -Pack $staged -Port 32296 -RunId $packagePlan.run_id -LogRoot $packageRun
}
$networkSmoke=& (Join-Path $project 'test/run_net_test.ps1') -Godot $Engine -Pack $staged -Clients 3 -Port 32312 -RunId $packagePlan.run_id -LogRoot (Join-Path $packageRun 'supplied_network_smoke') -ReturnResult
if(-not $networkSmoke.passed -or $networkSmoke.run_id -ne $packagePlan.run_id -or $networkSmoke.fixture -ne 'supplied_network_smoke'){throw 'Packaged connect-and-play smoke failed; current EXE remains intact.'}
& $python (Join-Path $PSScriptRoot 'test_workflow.py') package-commit --project $project --engine $Engine --pack $staged
if($LASTEXITCODE -ne 0){throw 'Source or test evidence changed during packaging; current EXE remains intact.'}
if((Get-FileHash -LiteralPath $stagedLock).Hash -ne $verifiedLockHash){throw 'Exported persistence lock changed during validation.'}
if($VerifyOnly){Write-Output ('VERIFIED ONLY: '+$staged);Write-Output ('COMPANION: '+$stagedLock);return}
if((Latest).FullName -ne $target.FullName){throw 'Milestone name changed during build; rerun to select it.'}
$backup=Join-Path $build ('backup-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+$target.Name)
Copy-Item -LiteralPath $target.FullName -Destination $backup
if(Test-Path -LiteralPath $installedLock -PathType Leaf){
 if((Get-FileHash -LiteralPath $installedLock).Hash -ne $verifiedLockHash){throw 'The target directory contains a different persistence-lock DLL. Install this pair in its own directory to preserve earlier builds.'}
}else{
 Copy-Item -LiteralPath $stagedLock -Destination $installedLock
}
if((Get-FileHash -LiteralPath $installedLock).Hash -ne $verifiedLockHash){throw 'Installed persistence-lock hash mismatch.'}
Copy-Item -LiteralPath $staged -Destination $target.FullName -Force
if((Get-FileHash -LiteralPath $target.FullName).Hash -ne (Get-FileHash -LiteralPath $staged).Hash){throw 'Installed build hash mismatch.'}
Write-Output ('UPDATED: '+$target.FullName)
Write-Output ('COMPANION: '+$installedLock)
Write-Output ('BACKUP: '+$backup)
Write-Output ('SOURCE: '+$fingerprint)
