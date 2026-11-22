param(
    [int]$Workers = 2,
    [int]$RunSeconds = 40,
    [switch]$Keep
)
# End-to-end check of the training controls in a throwaway run folder (never the real run): start, refuse a
# second start, collect shards, stop with a checkpoint, then resume from it and stop again. Prints the workers'
# combined speed. Deletes the folder afterwards unless -Keep.
$ErrorActionPreference = 'Stop'
$training = Join-Path (Split-Path $PSScriptRoot -Parent) 'training'
. (Join-Path $training 'training_common.ps1')
$run = Join-Path $env:TEMP ("mob-training-smoke-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$failures = 0
function Check([bool]$Condition, [string]$Label) {
    if ($Condition) { "PASS $Label" } else { "FAIL $Label"; $script:failures++ }
}

try {
    & (Join-Path $training 'start_training.ps1') -RunDir $run -Workers $Workers | Out-Host
    $processes = @(Get-TrainingProcesses $run)
    Check ($processes.Count -eq $Workers + 1) "the trainer and $Workers workers start"
    Check (@($processes | Where-Object { $_.Process.PriorityClass -ne 'BelowNormal' }).Count -eq 0) 'they run at below-normal priority'
    $second = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $training 'start_training.ps1') -RunDir $run -Workers 1
    Check ($LASTEXITCODE -eq 1 -and @(Get-TrainingProcesses $run).Count -eq $Workers + 1) 'a second start is refused while training runs'

    Start-Sleep -Seconds $RunSeconds
    $shards = @(Get-ChildItem (Join-Path $run 'shards') -Filter '*.shard').Count
    $progress = @(Get-ChildItem (Join-Path $run 'workers') -Filter 'w*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json })
    $speed = ($progress | Measure-Object -Property rows_per_second -Sum).Sum
    Check ($progress.Count -eq $Workers) "every worker reports progress ($('{0:N0}' -f $speed) decisions per second together)"
    $metrics = Join-Path $run 'logs\metrics.jsonl'
    Check ($shards -gt 0 -or (Test-Path $metrics)) "workers write shards for the trainer ($shards waiting)"

    & (Join-Path $training 'stop_training.ps1') -RunDir $run -TimeoutSeconds 120 | Out-Host
    Check (@(Get-TrainingProcesses $run).Count -eq 0) 'stopping ends every training process'
    $latest = Join-Path $run 'checkpoints\latest.json'
    Check (Test-Path $latest) 'the trainer saves a checkpoint when stopped'
    $stopped = (Get-Content (Join-Path $run 'trainer.json') -Raw | ConvertFrom-Json)
    Check ($stopped.state -eq 'stopped') 'the trainer records that it stopped cleanly'

    & (Join-Path $training 'start_training.ps1') -RunDir $run -Workers 1 | Out-Host
    $deadline = (Get-Date).AddSeconds(60)
    $resumed = $false
    while (-not $resumed -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $resumed = @(Get-ChildItem (Join-Path $run 'logs') -Filter 'trainer-*.log' | Select-String -Pattern 'Resumed from').Count -gt 0
    }
    Check $resumed 'a restart resumes from the checkpoint'
    $manifest = Get-Content (Join-Path $run 'policy\manifest.json') -Raw | ConvertFrom-Json
    Check ($manifest.version -gt $stopped.version) 'the resumed policy gets a newer version for the workers'
    & (Join-Path $training 'stop_training.ps1') -RunDir $run -TimeoutSeconds 120 | Out-Host
    Check (@(Get-TrainingProcesses $run).Count -eq 0) 'the resumed run stops too'
    $errors = @(Get-ChildItem (Join-Path $run 'logs') -Filter '*.err' | Select-String -Pattern 'SCRIPT ERROR|Traceback|Parse Error')
    Check ($errors.Count -eq 0) 'no script errors in any log'
    if ($errors.Count -gt 0) { $errors | Select-Object -First 5 | ForEach-Object { "  $_" } }
}
finally {
    foreach ($entry in @(Get-TrainingProcesses $run)) { Stop-Process -Id $entry.Process.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
    if (-not $Keep) { Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue } else { "Kept $run" }
}
if ($failures -gt 0) { throw "$failures training smoke check(s) failed." }
'Training smoke test passed.'
exit 0
