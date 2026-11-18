param(
    [string]$Script = 'res://neural_arena/arena_headless.gd',
    [string[]]$Arguments = @(),
    [string]$Godot = 'C:\Users\Josiah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [string]$DataRoot = (Join-Path $env:TEMP 'mystical_garden_arena_tests')
)
# Runs an arena script headless with its own user data folder, so real saves are never in reach.
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$env:APPDATA = Join-Path $DataRoot 'roaming'
$env:LOCALAPPDATA = Join-Path $DataRoot 'local'
New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
$output = & $Godot --headless --path $project --script $Script -- @Arguments *>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$output
$errors = @($output | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:|Parse Error' })
"ENGINE_ERRORS $($errors.Count)"
exit $(if ($code -ne 0 -or $errors.Count -gt 0) { 1 } else { 0 })
