@echo off
rem Compares the scripted brain with the run folder's newest checkpoint and a few milestones on identical fights,
rem and diagnoses the critic. Reads the run folder only; the report opens in evaluations\<time>\report.md.
rem Extra options go to evaluate.py, for example:  "Evaluate Brains.cmd" --episodes 400 --checkpoints C:\copies\ckpt_0009499.pt
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0training_common.ps1'; $s = Get-TrainingSettings; & $s.python '%~dp0evaluate.py' %*"
pause
