param(
    [string]$RunDir = '',
    [int]$TimeoutSeconds = 300
)
# Asks training to stop: workers finish their episode and write it, the trainer saves a checkpoint. Waits for them.
# Anything still running after the timeout is ended; every file is written atomically, so nothing is corrupted,
# and the trainer resumes from its last checkpoint.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'training_common.ps1')
$settings = Get-TrainingSettings
$RunDir = Resolve-RunDir $RunDir $settings
if (-not (Test-Path $RunDir)) { "No training run in $RunDir."; exit 0 }
New-Item -ItemType File -Force -Path (Join-Path $RunDir 'STOP') | Out-Null

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    $running = @(Get-TrainingProcesses $RunDir)
    if ($running.Count -eq 0) { break }
    "Waiting for $($running.Count) training processes to finish..."
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)

$running = @(Get-TrainingProcesses $RunDir)
foreach ($entry in $running) {
    "Ending $($entry.Role) (process $($entry.Process.Id)), which did not stop in time."
    Stop-Process -Id $entry.Process.Id -Force -Confirm:$false -ErrorAction SilentlyContinue
}
Remove-Item (Join-Path $RunDir 'processes.json') -ErrorAction SilentlyContinue
$trainer = Join-Path $RunDir 'trainer.json'
if (Test-Path $trainer) {
    $state = Get-Content $trainer -Raw | ConvertFrom-Json
    "Training stopped at policy $($state.version) after $('{0:N0}' -f $state.samples) decisions ($($state.hours) hours of training)."
} else {
    'Training stopped.'
}
