param(
    [string]$Godot = 'C:\Users\Josiah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [string]$DataRoot = (Join-Path $env:TEMP 'mystical_garden_bench')
)
# Measures simulation and arena speed against mob_sim/perf/budgets.json.
# Fails when any measurement drops below its floor. Targets are reported but never fail.
# Uses its own user data folder, so real saves are never in reach.
$ErrorActionPreference = 'Stop'
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$budgets = Get-Content -Raw -LiteralPath (Join-Path $project 'mob_sim\perf\budgets.json') | ConvertFrom-Json
$env:APPDATA = Join-Path $DataRoot 'roaming'
$env:LOCALAPPDATA = Join-Path $DataRoot 'local'
New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
$enemies = '--enemies=rootbound:5,nightbloom:3,thornmaw:3,gallhorn:2,willow:2,wasp:2,colossus:1,bellcap:1,orchid:1'
$brains = [ordered]@{ neural = 'res://ai/training/out/policy.bin'; scripted = 'scripted'; legacy = '' }

function Invoke-Godot([string[]]$Arguments, [string]$Marker) {
    $output = & $Godot --headless --path $project @Arguments *>&1 | ForEach-Object { "$_" }
    $errors = @($output | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:|Parse Error' })
    if ($errors.Count -gt 0) { $errors | Select-Object -First 5; throw "Engine errors while measuring $Marker." }
    $line = $output | Where-Object { $_ -like "$Marker *" } | Select-Object -Last 1
    if (-not $line) { throw "No $Marker line was printed." }
    return ($line.Substring($Marker.Length + 1) | ConvertFrom-Json)
}

$rows = @()
$sim = Invoke-Godot @('--script', 'res://mob_sim/tests/mob_sim_bench.gd', '--', 'budget') 'SIM_BUDGET_RESULT'
foreach ($count in '20', '100') {
    $budget = $budgets.sim.$count
    $result = $sim.$count
    $systems = $result.systems
    $rows += [pscustomobject]@{ Scenario = "Simulation, $count mobs"; TimesRealTime = $result.times_real_time; Floor = $budget.floor; Target = $budget.target
        Detail = "ms/tick: perception $($systems.perception), decision $($systems.decision), executors $($systems.executors), abilities $($systems.abilities), movement $($systems.movement)" }
}
foreach ($name in $brains.Keys) {
    $arguments = @('--script', 'res://neural_arena/arena_headless.gd', '--', '--rounds=2', '--bots=4', $enemies, '--round-seconds=60', '--seed=7', '--profile')
    if ($brains[$name]) { $arguments += "--brain=$($brains[$name])" }
    $result = Invoke-Godot $arguments 'ARENA_SUMMARY'
    $budget = $budgets.arena.$name
    $profile = $result.profile
    $rows += [pscustomobject]@{ Scenario = "Arena, $name enemies"; TimesRealTime = $result.times_real_time; Floor = $budget.floor; Target = $budget.target
        Detail = "ms/tick: enemies $($profile.enemies), bots $($profile.bots), other game $($profile.other_game)" }
}
$rows | Format-Table -AutoSize -Wrap | Out-String -Width 220
$slow = @($rows | Where-Object { $_.TimesRealTime -lt $_.Floor })
if ($slow.Count -gt 0) { "BENCH FAILED: $($slow.Count) measurement(s) below their floor"; exit 1 }
'BENCH PASSED'
