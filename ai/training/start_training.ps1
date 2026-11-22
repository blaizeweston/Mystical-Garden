param(
    [string]$RunDir = '',
    [int]$Workers = 0
)
# Starts (or resumes) mob training in the background: the Python trainer and the Godot workers, all hidden and at
# below-normal priority so the computer stays usable. Progress resumes from the run folder's last good checkpoint.
# Stop with stop_training.ps1; check on it with training_status.ps1.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'training_common.ps1')
$settings = Get-TrainingSettings
$RunDir = Resolve-RunDir $RunDir $settings
if ($Workers -le 0) { $Workers = [int]$settings.workers }
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logs = Join-Path $RunDir 'logs'
$shards = Join-Path $RunDir 'shards'
New-Item -ItemType Directory -Force -Path $RunDir, $logs, $shards | Out-Null

$running = @(Get-TrainingProcesses $RunDir)
if ($running.Count -gt 0) {
    "Training is already running in $RunDir ($($running.Count) processes). Run stop_training.ps1 first."
    exit 1
}
foreach ($tool in @($settings.python, $settings.godot)) {
    if (-not (Test-Path $tool)) { throw "Not found: $tool (set it in ai\training\training.json)." }
}

# Clear the stop request and anything a power loss left half written.
Remove-Item (Join-Path $RunDir 'STOP') -ErrorAction SilentlyContinue
Get-ChildItem $shards -Filter '*.tmp' -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$started = @()
function Start-Hidden([string]$Role, [string]$File, [string[]]$Arguments, [string]$Folder) {
    $log = Join-Path $logs "$Role-$stamp"
    $process = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $Folder -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput "$log.log" -RedirectStandardError "$log.err"
    try { $process.PriorityClass = 'BelowNormal' } catch { }
    [pscustomobject]@{ role = $Role; pid = $process.Id; started = $process.StartTime.ToString('o') }
}

$started += Start-Hidden 'trainer' $settings.python @("`"$(Join-Path $PSScriptRoot 'train.py')`"", '--run-dir', "`"$RunDir`"") $PSScriptRoot
for ($worker = 0; $worker -lt $Workers; $worker++) {
    $arguments = @('--headless', '--path', "`"$project`"", '--script', 'res://ai/training_worker.gd', '--', '--run-dir', "`"$RunDir`"", '--worker', "$worker")
    $started += Start-Hidden ('worker{0:D2}' -f $worker) $settings.godot $arguments $project
}
$record = [pscustomobject]@{ started = (Get-Date).ToString('o'); processes = $started }
$record | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $RunDir 'processes.json')
"Training started in $RunDir with $Workers workers. Logs: $logs"
"Stop it any time with stop_training.ps1; it resumes from where it left off."
