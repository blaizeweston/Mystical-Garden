@echo off
rem Shows how mob training is going.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0training_status.ps1" %*
pause
