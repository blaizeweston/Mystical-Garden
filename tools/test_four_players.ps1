param(
 [string]$Engine=(Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe'),
 [string]$Pack='', [int]$Port=32295, [string]$LogPrefix="four-players",
 [string]$RunId='', [string]$LogRoot=''
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $RunId){$RunId=[Guid]::NewGuid().ToString('N')}
if(-not $LogRoot){
 if($LogPrefix -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid log prefix.'}
 $LogRoot=Join-Path $project ".godot/validation/executions/$LogPrefix-$RunId"
}
. (Join-Path $PSScriptRoot 'validation_python.ps1')
$python=Find-ValidationPython
$fixtureArgs=@((Join-Path $PSScriptRoot 'validation_execution.py'),'--project',$project,'--engine',$Engine,
 '--fixture','four_players_coop','--kind','party','--port',"$Port",'--run-id',$RunId,'--log-root',$LogRoot)
if($Pack){$fixtureArgs+=@('--pack',$Pack)}
& $python @fixtureArgs
if($LASTEXITCODE -ne 0){throw "Four-player validation failed. See $LogRoot."}
