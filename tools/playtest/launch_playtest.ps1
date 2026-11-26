[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Build','Approve','Repository')][string]$Mode,
 [string]$Version='',
 [string]$ArchiveRoot='',
 [string]$Config='',
 [string]$WorkspaceRoot='',
 [string]$StageRoot='',
 [string]$EvidenceRoot='',
 [string]$Engine='',
 [string]$ExpectedRevision='',
 [switch]$DeveloperTools,
 [switch]$LegacyDefaults,
 [switch]$PlanOnly
)

$ErrorActionPreference='Stop'
$project=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$parent=Split-Path -Parent $project
$desktop=Join-Path $env:LOCALAPPDATA 'GitHubDesktop'
$interactive=-not $Version -and -not $PlanOnly -and $Mode -ne 'Repository'
$exitCode=0

try {
 if($Mode -eq 'Repository'){
  $desktopCli=Join-Path $desktop 'bin\github.bat'
  if(-not (Test-Path -LiteralPath $desktopCli -PathType Leaf)){throw 'GitHub Desktop could not be found.'}
  & $desktopCli open $project
  if($LASTEXITCODE -ne 0){throw 'GitHub Desktop could not open the local repository.'}
  return
 }

 $installed=Get-Command pwsh.exe -CommandType Application -All -ErrorAction SilentlyContinue |
  Where-Object { $_.Source -notlike '*\WindowsApps\OpenAI.CodexPrimaryRuntime*' } | Select-Object -First 1
 $pwsh=if($installed){$installed.Source}else{
  $standard=Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
  if(Test-Path -LiteralPath $standard -PathType Leaf){$standard}else{
   Get-AppxPackage -Name 'OpenAI.CodexPrimaryRuntime*' | Sort-Object Version -Descending | ForEach-Object {
    $candidate=Join-Path $_.InstallLocation 'dependencies\native\powershell\pwsh.exe'
    if(Test-Path -LiteralPath $candidate -PathType Leaf){$candidate}
   } | Select-Object -First 1
  }
 }
 if(-not $pwsh){throw 'PowerShell 7 is required for the playtest workflow.'}
 $git=Get-Command git.exe -CommandType Application -All -ErrorAction SilentlyContinue |
  Where-Object { $_.Source -notlike '*\WindowsApps\OpenAI.CodexPrimaryRuntime*' } | Select-Object -First 1
 $gitPath=if($git){$git.Source}elseif(Test-Path -LiteralPath $desktop -PathType Container){
  Get-ChildItem -LiteralPath $desktop -Directory -Filter 'app-*' |
   Sort-Object { [version]($_.Name.Substring(4)) } -Descending | ForEach-Object {
    $candidate=Join-Path $_.FullName 'resources\app\git\cmd\git.exe'
    if(Test-Path -LiteralPath $candidate -PathType Leaf){$candidate}
   } | Select-Object -First 1
 }
 if(-not $gitPath){throw 'Git for Windows or GitHub Desktop is required for the playtest workflow.'}
 $oldPath=$env:Path
 $env:Path="$(Split-Path -Parent $pwsh);$(Split-Path -Parent $gitPath);$oldPath"

 if($interactive){
  Write-Host "Mystical Garden - $Mode playtest" -ForegroundColor Cyan
  $Version=(Read-Host 'Version (e.g. 0.1.0-playtest.2, or Enter to cancel)').Trim()
  if(-not $Version){return}
  if(-not $ArchiveRoot){
   $ArchiveRoot=(Read-Host 'Archive directory override (Enter to use the workspace default)').Trim().Trim('"')
  }
 }
 if(-not $Version){throw 'Specify -Version with -PlanOnly.'}
 if($LegacyDefaults -and $Config){throw 'Select either -LegacyDefaults or -Config.'}
 if(-not $LegacyDefaults -and -not $Config){$Config=Join-Path $parent 'Tools\workspace.json'}

 $documents=Join-Path $env:USERPROFILE 'Documents'
 $history=@((Join-Path $parent 'Releases'),(Join-Path $documents 'MG-Playtests'),
  (Join-Path $documents 'Codex\MG7'),(Join-Path $documents 'Codex\MGFixCache'))
 $options=@{Version=$Version}
 if($Config){$options.Config=$Config}
 if($ArchiveRoot){$options.ArchiveRoot=$ArchiveRoot}
 if($Mode -eq 'Build'){
  $options.HistoricalArchiveRoots=$history
  foreach($name in @('WorkspaceRoot','StageRoot','EvidenceRoot','Engine','ExpectedRevision')){
   if(Get-Variable -Name $name -ValueOnly){$options[$name]=Get-Variable -Name $name -ValueOnly}
  }
  & (Join-Path $project 'tools\build_playtest.ps1') @options -DeveloperTools:$DeveloperTools -PlanOnly:$PlanOnly
 }else{
  if($WorkspaceRoot -or $StageRoot -or $EvidenceRoot -or $Engine -or $ExpectedRevision -or $DeveloperTools){
   throw 'Build-only overrides are unavailable in Approve mode.'
  }
  $approve=Join-Path $PSScriptRoot 'approve_playtest.ps1'
  $preview=& $approve @options -HistoricalArchiveRoots $history -PlanOnly | Out-String
  if($PlanOnly){Write-Output $preview.Trim();return}
  $selection=$preview | ConvertFrom-Json
  Write-Host "Release $($selection.version) at $($selection.git_commit)"
  Write-Host "Archive: $($selection.location)"
  Write-Host "ZIP SHA-256: $($selection.zip_sha256)"
  Write-Host "Manifest SHA-256: $($selection.manifest_sha256)"
  if($selection.already_approved){throw 'This release already has approval evidence.'}
  Write-Host "Approval creates the local annotated tag $($selection.git_tag)."
  Write-Host 'Complete desktop and separate-PC co-op checks before approving.'
  if((Read-Host 'Type APPROVE to continue') -cne 'APPROVE'){return}
  $options.ArchiveRoot=$selection.archive
  & $approve @options -ExpectedZipSha256 $selection.zip_sha256 -ExpectedManifestSha256 $selection.manifest_sha256
 }
} catch {
 Write-Host $_.Exception.Message -ForegroundColor Red
 $exitCode=1
} finally {
 if($oldPath){$env:Path=$oldPath}
 if($interactive -and $Version){[void](Read-Host 'Press Enter to close')}
}
exit $exitCode
