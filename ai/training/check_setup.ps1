param(
    [string]$RunDir = '',
    [switch]$SkipWorker
)
# Checks that this computer can train: Godot, Python with PyTorch and its GPU, the native simulation, the asset
# import, the run folder and its checkpoint. Then plays one training episode into a throwaway folder (unless
# -SkipWorker) to prove the whole worker path. Prints what is missing and a worker count for this computer.
# Changes nothing outside a temporary folder.
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'training_common.ps1')
$settings = Get-TrainingSettings
$RunDir = Resolve-RunDir $RunDir $settings
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$problems = 0
function Report([bool]$Ok, [string]$Label, [string]$Fix = '') {
    if ($Ok) { "OK    $Label" } else { "MISS  $Label"; if ($Fix) { "      -> $Fix" }; $script:problems++ }
}

"Project: $project"
$local = Join-Path $PSScriptRoot 'training.local.json'
"Settings: training.json$(if (Test-Path $local) { ' + training.local.json' } else { ' (no training.local.json; paths come from training.json)' })"

$godotOk = $settings.godot -and (Test-Path $settings.godot)
Report $godotOk "Godot at $($settings.godot)" 'Install Godot 4.7.2 (console build) and set "godot" in training.local.json.'
if ($godotOk) {
    $version = (& $settings.godot --version 2>$null | Select-Object -First 1)
    Report ($version -like '4.7.2*') "Godot version $version" 'Training was built with Godot 4.7.2; use that version.'
}

$pythonOk = $settings.python -and (Test-Path $settings.python)
Report $pythonOk "Python at $($settings.python)" 'Create a Python environment and set "python" in training.local.json.'
if ($pythonOk) {
    $probe = & $settings.python -c "import json, torch, numpy; print(json.dumps({'torch': torch.__version__, 'cuda': torch.cuda.is_available(), 'gpu': torch.cuda.get_device_name(0) if torch.cuda.is_available() else ''}))" 2>$null
    $torch = $null
    try { $torch = $probe | Select-Object -Last 1 | ConvertFrom-Json } catch { }
    Report ($null -ne $torch) "PyTorch and NumPy$(if ($torch) { " (torch $($torch.torch))" })" 'pip install -r ai\training\requirements.txt (see the CUDA note in that file).'
    if ($torch) { Report ([bool]$torch.cuda) "GPU for training: $(if ($torch.cuda) { $torch.gpu } else { 'none (CPU only)' })" 'Install the CUDA build of PyTorch; without a GPU the trainer is very slow.' }
}

$dll = Join-Path $project 'mob_sim\bin\mob_nav.dll'
Report (Test-Path $dll) 'Native simulation (mob_sim\bin\mob_nav.dll)' 'Copy mob_nav.dll from a computer that built it (it is not in git), or build it with mob_sim\native\build.ps1.'

$latest = Join-Path $RunDir 'checkpoints\latest.json'
Report (Test-Path $latest) "Run folder with a checkpoint: $RunDir" 'Copy the run folder there, or set "run_dir" in training.local.json.'
if ((Test-Path $latest) -and $pythonOk) {
    $schemaCheck = & $settings.python -c "import sys; sys.path.insert(0, r'$PSScriptRoot'); import safe_files as S; from mob_schema import MobSchema; from pathlib import Path; l = S.load_checkpoint(Path(r'$RunDir') / 'checkpoints', log=lambda t: None); print('none' if l is None else ('same' if l[0]['schema_hash'] == MobSchema().hash_hex else 'different'), l[1].name if l else '', int(l[0]['samples']) if l else 0)" 2>$null | Select-Object -Last 1
    $parts = "$schemaCheck".Split(' ')
    Report ($parts[0] -eq 'same') "Checkpoint $($parts[1]) ($('{0:N0}' -f [long]$parts[2]) decisions) matches this code's schema" "Stop training, then run: & '$($settings.python)' '$PSScriptRoot\convert_checkpoint.py'"
}

if (-not $SkipWorker -and $godotOk -and $pythonOk -and (Test-Path $dll)) {
    $temp = Join-Path $env:TEMP ('mob-setup-check-' + (Get-Date -Format 'yyyyMMddHHmmss'))
    New-Item -ItemType Directory -Force -Path (Join-Path $temp 'policy') | Out-Null
    $policy = Join-Path $temp 'policy\policy_0000001.bin'
    & $settings.python -c "import sys; sys.path.insert(0, r'$PSScriptRoot'); import torch; from mob_net import MobPolicy, export_weights; from mob_schema import MobSchema; from pathlib import Path; torch.manual_seed(1); export_weights(MobPolicy(MobSchema()), Path(r'$policy'))" 2>$null
    if (Test-Path $policy) {
        $sha = (Get-FileHash $policy -Algorithm SHA256).Hash.ToLower()
        "{`"version`": 1, `"file`": `"policy_0000001.bin`", `"sha256`": `"$sha`"}" | Set-Content -Encoding ascii (Join-Path $temp 'policy\manifest.json')
        $began = Get-Date
        $output = & $settings.godot --headless --path $project --script res://ai/training_worker.gd -- --run-dir $temp --worker 0 --episodes 2 2>&1 | ForEach-Object { "$_" }
        $shard = $output | Where-Object { $_ -match '^Shard ' } | Select-Object -First 1
        Report ([bool]$shard) "A training worker plays episodes ($([int]((Get-Date) - $began).TotalSeconds) s): $shard" ("Worker output: " + (($output | Where-Object { $_ -match 'ERROR|failed' } | Select-Object -First 3) -join ' | '))
    } else {
        Report $false 'Exporting a test policy' 'The Python environment could not build the policy; see the PyTorch line above.'
    }
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}

$threads = [Environment]::ProcessorCount
$memory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
""
"This computer: $threads threads, $memory GB of memory. Workers set: $($settings.workers)."
"Each worker uses one thread and about 0.5 GB. Leave a few threads for the trainer and Windows, and watch the dashboard:"
"if the trainer is usually waiting, add workers; if waiting shards climb toward $($settings.shards.backlog), remove some."
if ($problems -gt 0) { ""; "$problems item(s) to fix before training here."; exit 1 }
""; 'Ready to train: run Start Training.cmd.'
exit 0
