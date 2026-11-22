@echo off
rem Starts or resumes mob training in the background. Safe to run again after a reboot.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_training.ps1" %*
pause
