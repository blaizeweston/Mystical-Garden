# Shared by start_training.ps1, stop_training.ps1 and training_status.ps1.

function Get-TrainingSettings {
    Get-Content (Join-Path $PSScriptRoot 'training.json') -Raw | ConvertFrom-Json
}

function Resolve-RunDir([string]$RunDir, $Settings) {
    if ($RunDir) { return $RunDir }
    if ($Settings.run_dir) { return $Settings.run_dir }
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Godot\mob-training\run'
}

# The training processes recorded by start_training.ps1 that are still running.
function Get-TrainingProcesses([string]$RunDir) {
    $path = Join-Path $RunDir 'processes.json'
    if (-not (Test-Path $path)) { return @() }
    $record = Get-Content $path -Raw | ConvertFrom-Json
    $running = @()
    foreach ($entry in $record.processes) {
        $process = Get-Process -Id $entry.pid -ErrorAction SilentlyContinue
        # A recorded id can be reused by an unrelated program after a reboot; match the start time too.
        if ($process -and $process.StartTime.ToString('o') -eq $entry.started) {
            $running += [pscustomobject]@{ Role = $entry.role; Process = $process }
        }
    }
    $running
}
