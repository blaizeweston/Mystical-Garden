@echo off
rem Opens the live training dashboard in your browser. Close this window to stop it; training is not affected.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-Content '%~dp0training.json' -Raw | ConvertFrom-Json; & $s.python '%~dp0dashboard.py'"
pause
