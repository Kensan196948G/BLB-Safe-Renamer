@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 > nul
cd /d "%~dp0"

echo BLB Safe Renamer - PreCheck
echo Current folder: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Rename-BlbSafe.ps1" -ListPath "%~dp0rename_map.txt" -BaseDir "%~dp0input" -LogDir "%~dp0logs"

echo.
echo PreCheck finished.
pause
