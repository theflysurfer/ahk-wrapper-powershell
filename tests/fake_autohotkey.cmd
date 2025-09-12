@echo off
REM Simulateur AutoHotkey pour tests - Simule le comportement d'AutoHotkey.exe
REM Usage: fake_autohotkey.exe script.ahk

echo [FAKE AutoHotkey] Starting simulation for: %1

REM Analyser le nom du fichier pour déterminer le comportement
echo %1 | findstr /i "error" >nul
if %errorlevel%==0 (
    echo [FAKE AutoHotkey] Error detected in filename, will show error dialog
    timeout /t 1 /nobreak >nul
    msg %username% "AutoHotkey Error" "Line 6: Illegal character '$' in global_variable$"
    exit /b 2
)

echo %1 | findstr /i "include" >nul
if %errorlevel%==0 (
    echo [FAKE AutoHotkey] Include error detected in filename
    timeout /t 1 /nobreak >nul
    msg %username% "AutoHotkey Include Error" "Could not include file: NonExistentFile.ahk"
    exit /b 1
)

REM Cas de succès - simuler un script qui reste actif
echo [FAKE AutoHotkey] Success case - script will stay running
echo [FAKE AutoHotkey] Press Ctrl+C to terminate or wait for timeout
timeout /t 30 /nobreak
exit /b 0
