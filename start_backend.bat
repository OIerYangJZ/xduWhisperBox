@echo off
setlocal

cd /d "%~dp0"
echo Starting backend server...
set BACKEND_PORT=18080
python backend\server.py
if errorlevel 1 (
  echo.
  echo Backend startup failed.
  pause
)
