param(
 [string]$Engine=(Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe'),
 [ValidateSet('Focused','Connected','Full')][string]$Mode='Connected',
 [switch]$PlanOnly,
 [string[]]$ChangedFiles=@(),
 [switch]$NoCache
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'validation_python.ps1')
$python=Find-ValidationPython
$command=if($PlanOnly){'plan'}else{'run'}
if($ChangedFiles.Count -and -not $PlanOnly){throw 'ChangedFiles is only for plan previews. Actual runs detect all changes automatically.'}
$arguments=@((Join-Path $PSScriptRoot 'test_workflow.py'),$command,'--project',$project,'--engine',$Engine,'--mode',$Mode.ToLowerInvariant())
if($NoCache){$arguments+='--no-cache'}
if($ChangedFiles.Count){$arguments+='--changed';$arguments+=$ChangedFiles}
if(-not $PlanOnly){
 & $python -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_*.py'
 if($LASTEXITCODE -ne 0){throw 'Validation planner self-tests failed.'}
}
& $python @arguments
if($LASTEXITCODE -ne 0){throw 'Validation failed. See .godot/validation/runs.'}
if(-not $PlanOnly){
 $report=Get-Content -LiteralPath (Join-Path $project '.godot/validation/latest-report.json') -Raw | ConvertFrom-Json
 if($report.release_ready){
  & $python (Join-Path $PSScriptRoot 'test_workflow.py') verify --project $project --engine $Engine
  if($LASTEXITCODE -ne 0){throw 'Validation evidence verification failed.'}
  & (Join-Path $PSScriptRoot 'runtime_fingerprint.ps1') -Project $project | Set-Content -Encoding utf8 (Join-Path $project '.godot/stabilization/validated-source.sha256')
 }else{Write-Output 'Focused checks passed. Run Connected validation before exporting.'}
}
