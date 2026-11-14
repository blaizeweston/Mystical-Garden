[CmdletBinding()]
param(
    [string]$GodotExe = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Godot_v4.7.2-stable_win64.exe')
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$engine = (Resolve-Path -LiteralPath $GodotExe).Path
$name = 'mg-terrain-' + [Guid]::NewGuid().ToString('N')
$profile = Join-Path ([IO.Path]::GetTempPath()) $name
New-Item -ItemType Directory -Path $profile | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'terrain-session.marker'), $name)

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $engine
$start.WorkingDirectory = $project
$start.Arguments = '--path "' + $project + '" --log-file "' + (Join-Path $profile 'engine.log') + '" -- --experimental-terrain'
$start.UseShellExecute = $false
$start.EnvironmentVariables['APPDATA'] = $profile
$start.EnvironmentVariables['LOCALAPPDATA'] = $profile
$start.EnvironmentVariables['MYSTICAL_TERRAIN_PROFILE'] = $profile
$process = [Diagnostics.Process]::Start($start)
Write-Output "Terrain experiment PID $($process.Id). Disposable profile at $profile"
