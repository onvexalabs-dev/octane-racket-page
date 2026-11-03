@echo off
setlocal
if not exist "%~dp0push-to-github.ps1" (
  echo ERROR: push-to-github.ps1 is missing from this folder.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-to-github.ps1"
if errorlevel 1 (
  echo.
  echo Upload failed. The error is shown above.
  pause
  exit /b 1
)
exit /b 0
