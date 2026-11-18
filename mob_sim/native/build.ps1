param(
    [string]$Toolchain = 'C:\Users\Josiah\Documents\Godot\toolchain\llvm-mingw-20251104-ucrt-x86_64',
    [string]$Interface = 'C:\Users\Josiah\Documents\Godot\toolchain\godot-4.7.2-interface'
)
# Builds and tests the engine-free core, then links the Godot extension into mob_sim/bin.
$ErrorActionPreference = 'Stop'
$native = $PSScriptRoot
$bin = Join-Path (Split-Path $native -Parent) 'bin'
$cc = Join-Path $Toolchain 'bin\x86_64-w64-mingw32-clang.exe'
$flags = @('-std=c11', '-Wall', '-Wextra', '-Werror', '-Wno-cast-function-type-mismatch', '-O2', '-fno-math-errno', '-ffp-contract=off')
$core = @('mob_nav.c', 'mob_policy.c', 'mob_obs.c') | ForEach-Object { Join-Path $native $_ }
New-Item -ItemType Directory -Force $bin | Out-Null

$test = Join-Path $bin 'mob_nav_test.exe'
& $cc @flags @core (Join-Path $native 'mob_nav_test.c') -o $test
if ($LASTEXITCODE -ne 0) { throw 'Core test build failed.' }
& $test
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }

$dll = Join-Path $bin 'mob_nav.dll'
& $cc @flags -shared -I $Interface @core (Join-Path $native 'mob_nav_gdextension.c') -o $dll
if ($LASTEXITCODE -ne 0) { throw 'Extension build failed.' }
"Built $dll"
