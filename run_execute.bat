@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 > nul
cd /d "%~dp0"

echo BLB Safe Renamer - Execute
echo Current folder: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Rename-BlbSafe.ps1" -ListPath "%~dp0rename_map.txt" -BaseDir "%~dp0." -Execute

echo.
echo Execute finished.
pause
