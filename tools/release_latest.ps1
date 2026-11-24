param([string]$Engine=(Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe'),[Alias('Target')][string]$TargetPath='', [switch]$Full, [switch]$VerifyOnly, [string]$PlaytestVersion='', [string]$PlaytestCommit='', [string]$InputManifestSha256='', [switch]$ExperimentalTerrain, [switch]$CombatAffinities)
$ErrorActionPreference='Stop'
# Historical alias requests isolated terrain only; gameplay is always modern.
if($CombatAffinities){$ExperimentalTerrain=$true}
if($ExperimentalTerrain -and -not $PlaytestVersion){throw 'Experimental terrain requires a versioned VerifyOnly build.'}
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if($PlaytestVersion){
 if(-not $VerifyOnly -or $TargetPath -or $PlaytestVersion -cnotmatch '\A(?:0|[1-9][0-9]{0,5})\.(?:0|[1-9][0-9]{0,5})\.(?:0|[1-9][0-9]{0,5})-playtest\.[1-9][0-9]{0,5}\z' -or $PlaytestCommit -cnotmatch '\A[0-9a-f]{40}\z' -or $InputManifestSha256 -cnotmatch '\A[0-9a-f]{64}\z'){
  throw 'Playtest export requires VerifyOnly and an exact version, commit and input digest.'
 }
}
# Remember the installed template location before isolating the game's profile.
if(-not $env:MYSTICAL_GODOT_TEMPLATE_DIR){
 $env:MYSTICAL_GODOT_TEMPLATE_DIR=Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
}
$env:APPDATA=Join-Path $project '.godot/stabilization-appdata'
$env:LOCALAPPDATA=Join-Path $project '.godot/stabilization-localappdata'
$build=Join-Path $project '.godot/release'
if($env:MYSTICAL_PLAYTEST_EXPORT_ROOT){
 if(-not $PlaytestVersion -or -not $VerifyOnly){throw 'An external stage is available only for playtest verification.'}
 $build=[IO.Path]::GetFullPath($env:MYSTICAL_PLAYTEST_EXPORT_ROOT)
 $parent=Split-Path -Parent $build
 if((Split-Path -Leaf $build) -cne 'export' -or (Split-Path -Leaf $parent) -cne (Split-Path -Leaf (Split-Path -Parent $project)) -or
    -not (Test-Path -LiteralPath $parent -PathType Container) -or (Test-Path -LiteralPath $build)){
  throw 'External stage must be the new export directory under the owned playtest attempt.'
 }
 for($part=$parent;$part;$part=Split-Path -Parent $part){
  if((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'External stage cannot cross a reparse point.'}
 }
}
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA,$build | Out-Null
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
if($PlaytestVersion){
 $target=[pscustomobject]@{BaseName="Mystical Garden $PlaytestVersion";Name='Mystical Garden.exe'}
}else{
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
}
$fingerprint=& (Join-Path $PSScriptRoot 'runtime_fingerprint.ps1') -Project $project
$stamp=Join-Path $project '.godot/stabilization/validated-source.sha256'
if(-not (Test-Path -LiteralPath $stamp) -or (Get-Content -LiteralPath $stamp -Raw).Trim() -ne $fingerprint){throw 'Runtime source changed since validation. Run validate_release.ps1 again.'}
$metadata=@{schema=2;milestone=$target.BaseName;built_utc=[DateTime]::UtcNow.ToString('o');source_fingerprint=$fingerprint;engine='4.7.2';checks=$results.Count}
$rules=Get-Content -LiteralPath (Join-Path $project 'combat_ruleset.gd') -Raw -Encoding utf8
$ruleVersion=[regex]::Match($rules,'(?m)^const ID := "([a-z0-9-]+)"\r?$')
if(-not $ruleVersion.Success){throw 'Modern gameplay identity is missing.'}
$metadata.combat_ruleset=$ruleVersion.Groups[1].Value
if($PlaytestVersion){
 $metadata.playtest_version=$PlaytestVersion
 $metadata.git_commit=$PlaytestCommit
 $metadata.input_manifest_sha256=$InputManifestSha256
 $metadata.save_root="Mystical Garden Playtest $PlaytestVersion"
 $metadata.persistence='guarded sessions with a version-specific save root'
 $metadata.persistence_label='guarded'
 if($ExperimentalTerrain){
  $mode=Get-Content -LiteralPath (Join-Path $project 'assets/terrain_m02/experimental/experiment_mode.gd') -Raw
  $modeVersion=[regex]::Match($mode,'const NETWORK_VERSION := "([a-z0-9-]+)"')
  if(-not $modeVersion.Success){throw 'Experimental terrain version is missing.'}
  $metadata.terrain_mode=$modeVersion.Groups[1].Value
 }
 $env:MYSTICAL_VALIDATION_DATA_DIR=$metadata.save_root
}
$manifest=Join-Path $project 'assets/content/build_manifest.json'
$preset=Join-Path $project 'export_presets.cfg'
$template=$packagePlan.release_template
if(-not $template -or (Get-FileHash -LiteralPath $template).Hash -ne $packagePlan.template){throw 'The Windows template differs from the package plan.'}
$stageDirectory=Join-Path $build ([Guid]::NewGuid().ToString('N').Substring(0,12))
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$staged=Join-Path $stageDirectory $(if($PlaytestVersion){'Mystical Garden.exe'}else{'Mystical Garden-staged.exe'})
$sourceLock=Join-Path $project 'assets/native/persistence_lock/b0_native_lock.dll'
$stagedLock=Join-Path $stageDirectory 'b0_native_lock.dll'
$installedLock=Join-Path $targetDirectory 'b0_native_lock.dll'
$log=Join-Path $build 'export.log'
$settings=Join-Path $project 'project.godot'
$originalSettings=[IO.File]::ReadAllBytes($settings)
$originalPreset=[IO.File]::ReadAllBytes($preset)
$originalManifest=[IO.File]::ReadAllBytes($manifest)
$importSettings=@{}
if($VerifyOnly){
 Get-ChildItem -LiteralPath (Join-Path $project 'assets') -Recurse -File -Filter '*.import' | ForEach-Object {
  $importSettings[$_.FullName]=[IO.File]::ReadAllBytes($_.FullName)
 }
}
try {
 $metadata | ConvertTo-Json | Set-Content -Encoding utf8 $manifest
 Copy-Item -LiteralPath $manifest -Destination (Join-Path $stageDirectory 'export-build.json')
 $text=Get-Content -LiteralPath $preset -Raw
 $text=$text.Replace(([regex]::Match($text,'(?m)^custom_template/release="[^"]*"')).Value,('custom_template/release="'+$template.Replace('\','/')+'"'))
 [IO.File]::WriteAllText($preset,$text,[Text.UTF8Encoding]::new($false))
 if($PlaytestVersion){
  $configuration=[IO.File]::ReadAllText($settings)
  $pattern='(?m)^config/custom_user_dir_name="Mystical Garden Prototype"\r?$'
  if([regex]::Matches($configuration,$pattern).Count -ne 1){throw 'Unexpected committed user-data configuration.'}
  $configuration=[regex]::Replace($configuration,$pattern,('config/custom_user_dir_name="'+$metadata.save_root+"`"`nconfig/mystical_playtest=true"))
  $releaseRoot='(?m)^config/custom_user_dir_name\.template_release="Mystical Garden Guarded 1"\r?$'
  if([regex]::Matches($configuration,$releaseRoot).Count -ne 1){throw 'Missing guarded release root.'}
  $configuration=[regex]::Replace($configuration,$releaseRoot,('config/custom_user_dir_name.template_release="'+$metadata.save_root+'"'))
  if($configuration -notmatch '(?m)^\[debug\]'){throw 'Missing Godot debug settings section.'}
  $configuration=[regex]::Replace($configuration,'(?m)^\[debug\]\r?$',"[debug]`nfile_logging/enable_file_logging=false`nfile_logging/enable_file_logging.pc=false")
  if($configuration -match '(?m)^\[editor\]'){throw 'Unexpected existing editor settings section.'}
  # Serialize Godot's export-time import pass. Embedded GLTF textures can
  # otherwise race the texture importer and rewrite committed metadata.
  $configuration+="`n[editor]`nimport/use_multiple_threads=false`n"
  [IO.File]::WriteAllText($settings,$configuration,[Text.UTF8Encoding]::new($false))
  Copy-Item -LiteralPath $settings -Destination (Join-Path $stageDirectory 'export-project.godot')
 }
 & $Engine --headless --path $project --export-release 'Windows Desktop' $staged *> $log
 $exportExit=$LASTEXITCODE
}finally {
 if($PlaytestVersion){[IO.File]::WriteAllBytes($settings,$originalSettings)}
 [IO.File]::WriteAllBytes($preset,$originalPreset)
 [IO.File]::WriteAllBytes($manifest,$originalManifest)
 if($VerifyOnly){
  $problems=@()
  $currentImports=@(Get-ChildItem -LiteralPath (Join-Path $project 'assets') -Recurse -File -Filter '*.import')
  foreach($file in $currentImports){
   if(-not $importSettings.ContainsKey($file.FullName)){$problems+=("Unexpected import sidecar: "+$file.FullName)}
  }
  foreach($path in $importSettings.Keys){
   $original=$importSettings[$path]
   if(-not (Test-Path -LiteralPath $path)){
    $problems+=("Missing import sidecar: "+$path)
    [IO.File]::WriteAllBytes($path,$original)
    continue
   }
   $current=[IO.File]::ReadAllBytes($path)
   if([Convert]::ToBase64String($original) -cne [Convert]::ToBase64String($current)){
    if([Text.Encoding]::UTF8.GetString($original).Replace("`r`n","`n") -cne [Text.Encoding]::UTF8.GetString($current).Replace("`r`n","`n")){
     $problems+=("Export changed import settings: "+$path)
    }
    [IO.File]::WriteAllBytes($path,$original)
   }
  }
  if($problems.Count){throw ($problems -join "`n")}
 }
}
if($exportExit -ne 0 -or -not (Test-Path -LiteralPath $staged)){throw 'Export failed; current EXE remains intact.'}
if($PlaytestVersion){
 if(Select-String -LiteralPath $log -Pattern '^\s*(?:(?:USER )?ERROR:|SCRIPT ERROR:|Parse Error:)' -Quiet){
  throw 'Godot reported an error while exporting the playtest. See the staged export log.'
 }
}
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
 for forbidden in ["res://test/net_test.gd","res://test/net_test.tscn","res://tests/playable.gd","res://tests/candidate_release_solo.gd","res://tests/candidate_release_party.gd","res://tools/make_natural_world.py","res://docs/SYSTEMS_REVIEW_2026-11-08.md","res://assets/source/natural_world.blend"]:
  if FileAccess.file_exists(forbidden): errors.append("Excluded resource present: "+forbidden);printerr("Excluded resource present: "+forbidden)
 if errors.is_empty(): print("PASS: packaged runtime catalogs and exclusions")
 quit(0 if errors.is_empty() else 1)
'@ | Set-Content -Encoding utf8 $smoke
Invoke-ValidationFixture 'package_startup' 'unit' $smoke $staged
foreach($testName in @($packagePlan.selected.unit)) {
 Invoke-ValidationFixture $testName 'unit' -PackPath $staged
}
foreach($testName in @($packagePlan.selected.pair)) {
 Invoke-ValidationFixture $testName 'pair' -PackPath $staged -Port 32291
}
foreach($testName in @($packagePlan.selected.party)) {
 Invoke-ValidationFixture $testName 'party' -PackPath $staged -Port 32296
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
