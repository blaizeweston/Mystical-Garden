param(
 [string[]]$InputPath=@(),
 [string]$OutputPath='',
 [string]$UtcOffset='+00:00'
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if(-not $InputPath.Count){$InputPath=@((Join-Path $project 'Gameplay logs'))}
if(-not $OutputPath){$OutputPath=Join-Path $project 'docs/gameplay-analysis'}
. (Join-Path $PSScriptRoot '../validation_python.ps1')
$python=Find-ValidationPython
$analysisArguments=@((Join-Path $PSScriptRoot 'analyze_session_logs.py'),'--input')+$InputPath+@('--output',$OutputPath,"--utc-offset=$UtcOffset")
& $python @analysisArguments
if($LASTEXITCODE -ne 0){throw 'Log analysis failed. The original logs were not changed.'}
