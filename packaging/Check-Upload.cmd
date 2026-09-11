@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem  Upload checker -- double-click this file, or drag a folder onto it.
rem
rem  This file does as little as possible on purpose. What gets checked is in
rem  upload-check.xml; the checking, and every "something is missing" message,
rem  is in Start-UploadCheck.ps1 next to it.
rem ---------------------------------------------------------------------------

chcp 65001 >nul 2>&1
title Upload checker

set "BOOTSTRAP=%~dp0Start-UploadCheck.ps1"

if not exist "%BOOTSTRAP%" (
    echo.
    echo   Start-UploadCheck.ps1 is missing from this folder.
    echo   Extract the whole ZIP and keep the files together.
    echo.
    pause
    exit /b 2
)

rem Windows PowerShell is on every Windows machine and is enough to run the
rem bootstrap, which is what reports a missing PowerShell 7. Either will do.
set "PS="
for %%P in (powershell.exe) do if not defined PS set "PS=%%~$PATH:P"
for %%P in (pwsh.exe) do if not defined PS set "PS=%%~$PATH:P"

if not defined PS (
    echo.
    echo   No PowerShell was found on this computer at all, which is unusual.
    echo   Ask whoever sent you this file for help.
    echo.
    pause
    exit /b 2
)

rem A dragged folder arrives as %1, quoted by Explorer when the path has a
rem space in it. %~1 takes those quotes off here, so the bootstrap is handed
rem a named -Folder argument rather than having to unpick one.
rem
rem A folder with an & in its name cannot be dragged onto any .cmd file:
rem Explorer leaves it unquoted and cmd splits the line before this script
rem starts. Picking it in the folder window works.
if "%~1"=="" (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP%"
) else (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP%" -Folder "%~1"
)
set "RESULT=%ERRORLEVEL%"

echo.
pause
exit /b %RESULT%
