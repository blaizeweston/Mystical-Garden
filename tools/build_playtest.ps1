[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$Version,
 [string]$ArchiveRoot='',
 [string]$Engine=(Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'validation_python.ps1')
$python=Find-ValidationPython
$arguments=@('-B',(Join-Path $PSScriptRoot 'playtest_release.py'),'--version',$Version,'--engine',$Engine)
if($ArchiveRoot){$arguments+=@('--archive',$ArchiveRoot)}
& $python @arguments
if($LASTEXITCODE -ne 0){throw 'Playtest build failed. See the retained staging evidence.'}
