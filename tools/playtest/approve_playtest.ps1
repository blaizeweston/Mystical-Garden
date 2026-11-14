[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Version, [string]$ArchiveRoot='', [string]$Config='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../validation_python.ps1')
$python=Find-ValidationPython
$arguments=@('-B',(Join-Path $PSScriptRoot '../playtest_release.py'),'--approve','--version',$Version)
if($Config){$arguments+=@('--config',$Config)}
if($ArchiveRoot){$arguments+=@('--archive',$ArchiveRoot)}
& $python @arguments
if($LASTEXITCODE -ne 0){throw 'Playtest approval failed.'}
