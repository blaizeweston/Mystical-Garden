@echo off
rem The dashboard, also reachable from other computers on this network at the addresses it prints.
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0training_common.ps1'; $s = Get-TrainingSettings; & $s.python '%~dp0dashboard.py' --lan"
pause
