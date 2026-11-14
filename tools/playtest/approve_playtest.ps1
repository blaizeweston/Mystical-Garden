[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$Version,
 [string]$ArchiveRoot='',
 [string]$Config='',
 [string[]]$HistoricalArchiveRoots=@(),
 [string]$ExpectedZipSha256='',
 [string]$ExpectedManifestSha256='',
 [switch]$PlanOnly
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../validation_python.ps1')
$python=Find-ValidationPython
$arguments=@('-B',(Join-Path $PSScriptRoot '../playtest_release.py'),'--approve','--version',$Version)
if($Config){$arguments+=@('--config',$Config)}
if($ArchiveRoot){$arguments+=@('--archive',$ArchiveRoot)}
if($PlanOnly){$arguments+='--plan'}
foreach($root in $HistoricalArchiveRoots){$arguments+=@('--history',$root)}
if($ExpectedZipSha256){$arguments+=@('--expected-zip',$ExpectedZipSha256)}
if($ExpectedManifestSha256){$arguments+=@('--expected-manifest',$ExpectedManifestSha256)}
& $python @arguments
if($LASTEXITCODE -ne 0){throw 'Playtest approval failed.'}
