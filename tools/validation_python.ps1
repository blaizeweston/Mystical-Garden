# Shared runtime discovery for validation and release tools.
function Find-ValidationPython {
 $bundled=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
 if(Test-Path -LiteralPath $bundled){return $bundled}
 foreach($name in @('python','python3')){
  $command=Get-Command $name -ErrorAction SilentlyContinue
  if($command){return $command.Source}
 }
 throw 'Python 3 is required for the validation planner.'
}
