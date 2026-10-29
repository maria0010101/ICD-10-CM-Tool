@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_windows.ps1" %*
if errorlevel 1 (
  echo Windows build failed. Review the error above. No executable ZIP is claimed.
) else (
  echo Actual executable ZIP and checksum are in dist.
)
pause
