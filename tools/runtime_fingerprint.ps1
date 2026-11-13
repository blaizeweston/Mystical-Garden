param([Parameter(Mandatory=$true)][string]$Project)
$files=Get-ChildItem -LiteralPath $Project -File | Where-Object {$_.Extension -in @('.gd','.tscn','.godot')}
$files+=Get-ChildItem -LiteralPath (Join-Path $Project 'assets') -Recurse -File | Where-Object {$_.FullName -notmatch '[\\/]source[\\/]' -and $_.Extension -notin @('.import','.uid') -and $_.Name -ne 'build_manifest.json'}
$entries=@($files | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($Project.Length+1).Replace('\','/')+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
$sha=[System.Security.Cryptography.SHA256]::Create()
([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))))).Replace('-','')
