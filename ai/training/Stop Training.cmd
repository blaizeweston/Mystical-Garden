@echo off
rem Stops mob training and saves its progress.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop_training.ps1" %*
pause
