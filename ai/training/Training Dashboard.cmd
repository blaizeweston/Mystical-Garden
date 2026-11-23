@echo off
rem Opens the live training dashboard in your browser. Close this window to stop it; training is not affected.
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0training_common.ps1'; $s = Get-TrainingSettings; & $s.python '%~dp0dashboard.py'"
pause
