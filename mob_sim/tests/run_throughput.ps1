param(
    [int]$Processes = 12,
    [string]$Script = 'res://mob_sim/tests/mob_nav_bench.gd',
    [string]$Godot = 'C:\Users\Josiah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe'
)
# Runs several headless simulations at once to measure sustained training speed.
$ErrorActionPreference = 'Stop'
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logs = Join-Path $env:TEMP ('mob_nav_throughput_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $logs | Out-Null
$running = @()
for ($i = 0; $i -lt $Processes; $i++) {
    $running += Start-Process -FilePath $Godot -PassThru -WindowStyle Hidden `
        -ArgumentList @('--headless', '--path', "`"$project`"", '--script', $Script, '--', 'throughput') `
        -RedirectStandardOutput (Join-Path $logs "$i.out") -RedirectStandardError (Join-Path $logs "$i.err")
}
$running | Wait-Process
$rates = foreach ($i in 0..($Processes - 1)) {
    $line = Select-String -LiteralPath (Join-Path $logs "$i.out") -Pattern 'THROUGHPUT_RESULT (.*)$'
    if (-not $line) { throw "Process $i produced no result. See $logs" }
    ($line.Matches[0].Groups[1].Value | ConvertFrom-Json).ticks_per_second
}
$stats = $rates | Measure-Object -Minimum -Maximum -Average -Sum
Remove-Item -LiteralPath $logs -Recurse -Force
[pscustomobject]@{
    processes = $Processes
    slowest_ticks_per_second = $stats.Minimum
    average_ticks_per_second = [math]::Round($stats.Average)
    combined_ticks_per_second = $stats.Sum
    slowest_times_real_time = [math]::Round($stats.Minimum / 60, 1)
} | ConvertTo-Json
