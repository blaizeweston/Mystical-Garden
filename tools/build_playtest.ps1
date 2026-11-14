[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$Version,
 [string]$ArchiveRoot='',
 [string]$Engine='',
 [string]$Config='',
 [string]$WorkspaceRoot='',
 [string]$StageRoot='',
 [string]$EvidenceRoot='',
 [string]$ExpectedRevision='',
 [switch]$PlanOnly
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'validation_python.ps1')
$python=Find-ValidationPython
$arguments=@('-B',(Join-Path $PSScriptRoot 'playtest_release.py'),'--version',$Version)
if(-not $Config -and -not $Engine){$Engine=Join-Path $PSScriptRoot '../../Godot_v4.7.2-stable_win64_console.exe'}
$overrides=[ordered]@{'archive'=$ArchiveRoot;'engine'=$Engine;'config'=$Config;'workspace'=$WorkspaceRoot;'stage'=$StageRoot;'evidence'=$EvidenceRoot;'expected-revision'=$ExpectedRevision}
foreach($entry in $overrides.GetEnumerator()){if($entry.Value){$arguments+=@(('--'+$entry.Key),$entry.Value)}}
if($PlanOnly){$arguments+='--plan'}
& $python @arguments
if($LASTEXITCODE -ne 0){throw 'Playtest build failed. See the retained staging evidence.'}
