@echo off
cd /d "%~dp0"
where py.exe >nul 2>&1
if not errorlevel 1 (
  py -3 manager.py
) else (
  python manager.py
)
if errorlevel 1 pause
