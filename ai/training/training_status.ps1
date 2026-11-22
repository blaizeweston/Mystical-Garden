param(
    [string]$RunDir = ''
)
# Shows whether training is running and how it is going.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'training_common.ps1')
$settings = Get-TrainingSettings
$RunDir = Resolve-RunDir $RunDir $settings
if (-not (Test-Path $RunDir)) { "No training run in $RunDir yet."; exit 0 }

$running = @(Get-TrainingProcesses $RunDir)
$workers = @($running | Where-Object { $_.Role -like 'worker*' }).Count
$trainerUp = @($running | Where-Object { $_.Role -eq 'trainer' }).Count -gt 0
"Run folder: $RunDir"
"Running: trainer $(if ($trainerUp) { 'yes' } else { 'no' }), $workers workers$(if (Test-Path (Join-Path $RunDir 'STOP')) { ' (stop requested)' })"

$trainer = Join-Path $RunDir 'trainer.json'
if (Test-Path $trainer) {
    $state = Get-Content $trainer -Raw | ConvertFrom-Json
    "Trainer: $($state.state), policy $($state.version), $('{0:N0}' -f $state.samples) decisions, $($state.updates) updates, $($state.hours) hours, last seen $($state.time)"
}
$speed = 0.0
foreach ($file in Get-ChildItem (Join-Path $RunDir 'workers') -Filter 'w*.json' -ErrorAction SilentlyContinue) {
    $progress = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $speed += [double]$progress.rows_per_second
}
if ($speed -gt 0) { "Workers: about $('{0:N0}' -f $speed) decisions per second together (latest shard of each)" }
$waiting = @(Get-ChildItem (Join-Path $RunDir 'shards') -Filter '*.shard' -ErrorAction SilentlyContinue).Count
"Shards waiting for the trainer: $waiting"
$latest = Join-Path $RunDir 'checkpoints\latest.json'
if (Test-Path $latest) { "Latest checkpoint: $((Get-Content $latest -Raw | ConvertFrom-Json).file) ($((Get-Item $latest).LastWriteTime))" }

$metrics = Join-Path $RunDir 'logs\metrics.jsonl'
if (Test-Path $metrics) {
    # A power loss can cut the last line short; use the last line that reads.
    $lines = @(Get-Content $metrics -Tail 5)
    [array]::Reverse($lines)
    foreach ($line in $lines) {
        try { $last = $line | ConvertFrom-Json } catch { continue }
        "Last update: $($last.time), wipe rate $([math]::Round($last.wipe_rate * 100))%, mob life return $($last.life_return), entropy $($last.entropy)"
        if ($null -ne $last.explore_found_rate) { "Explore episodes: party found in $([math]::Round($last.explore_found_rate * 100))% (first sight after $($last.explore_first_sight_s) s on average)" }
        break
    }
}
