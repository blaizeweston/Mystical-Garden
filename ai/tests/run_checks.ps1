param(
    [string]$Python = 'C:\Users\Josiah\Documents\Godot\toolchain\mob-ai-venv\Scripts\python.exe',
    [string]$Godot = 'C:\Users\Josiah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe'
)
# Exports the Python model, proves Godot matches it, then compares both schema parsers.
# A script error fails the run even when every written check passed.
$ErrorActionPreference = 'Continue'
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$check = Join-Path $project 'ai\training\check_model.py'

function Invoke-GodotCheck([string]$Script) {
    $output = & $Godot --headless --path $project --script $Script *>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $output | Where-Object { $_ -notmatch '^PASS ' }
    $errors = @($output | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:|Parse Error' })
    if ($code -ne 0 -or $errors.Count -gt 0) { throw "$Script failed with exit code $code and $($errors.Count) engine error(s)." }
}

& $Python $check *>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { throw 'The Python model checks failed.' }
Invoke-GodotCheck 'res://mob_sim/tests/mob_nav_binding.gd'
Invoke-GodotCheck 'res://mob_sim/tests/mob_sim_contracts.gd'
Invoke-GodotCheck 'res://ai/tests/mob_ai_checks.gd'
& $Python $check compare *>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { throw 'The schema comparison failed.' }
'All neural net checks passed.'
