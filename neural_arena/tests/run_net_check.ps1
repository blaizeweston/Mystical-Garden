param(
    [int]$Port = 24681,
    [string]$Godot = 'C:\Users\Josiah\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe'
)
# Starts a headless arena host and guest on this machine, each with its own user data folder.
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$root = Join-Path $env:TEMP ('mystical_garden_arena_net_' + [guid]::NewGuid().ToString('N'))
$peers = @()
foreach ($role in 'host', 'guest') {
    $data = Join-Path $root $role
    New-Item -ItemType Directory -Force (Join-Path $data 'roaming'), (Join-Path $data 'local') | Out-Null
    $env:APPDATA = Join-Path $data 'roaming'
    $env:LOCALAPPDATA = Join-Path $data 'local'
    $peers += Start-Process -FilePath $Godot -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $data 'out.txt') -RedirectStandardError (Join-Path $data 'err.txt') `
        -ArgumentList @('--headless', '--path', "`"$project`"", '--script', 'res://neural_arena/tests/arena_net_peer.gd', '--', $role, "--port=$Port")
    if ($role -eq 'host') { Start-Sleep -Seconds 6 }
}
$peers | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
$peers | Where-Object { -not $_.HasExited } | Stop-Process -Force
$failed = $false
foreach ($peer in $peers) {
    $peer.WaitForExit()
    if ($peer.ExitCode -ne 0) { $failed = $true }
}
foreach ($role in 'host', 'guest') {
    $text = Get-Content -LiteralPath (Join-Path $root "$role\out.txt")
    $errors = @($text + (Get-Content -LiteralPath (Join-Path $root "$role\err.txt")) | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:' })
    $result = $text | Where-Object { $_ -like 'NET_RESULT*' }
    "$role $result"
    "$role engine errors: $($errors.Count)"
    $errors | Select-Object -First 8
    if (-not $result -or $errors.Count -gt 0) { $failed = $true }
}
Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
if ($failed) { 'MULTIPLAYER CHECK FAILED'; exit 1 }
'MULTIPLAYER CHECK PASSED'
