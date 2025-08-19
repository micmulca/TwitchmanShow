@echo off
echo ========================================
echo TwitchMan Conversation Test Environment
echo ========================================
echo.
echo This script will help you start the conversation test environment.
echo.
echo Prerequisites:
echo 1. LM Studio must be running with your model loaded
echo 2. Local server must be started on http://localhost:1234
echo 3. Godot must be installed and accessible
echo.
echo Press any key to continue...
pause >nul

echo.
echo Starting Godot with the test scene...
echo.

REM Try to find Godot in common locations
set GODOT_PATH=""

if exist "C:\Program Files\Godot\Godot_v4.x.x-stable_win64.exe" (
    set GODOT_PATH="C:\Program Files\Godot\Godot_v4.x.x-stable_win64.exe"
) else if exist "C:\Program Files (x86)\Godot\Godot_v4.x.x-stable_win64.exe" (
    set GODOT_PATH="C:\Program Files (x86)\Godot\Godot_v4.x.x-stable_win64.exe"
) else if exist "%USERPROFILE%\AppData\Local\Programs\Godot\Godot_v4.x.x-stable_win64.exe" (
    set GODOT_PATH="%USERPROFILE%\AppData\Local\Programs\Godot\Godot_v4.x.x-stable_win64.exe"
) else (
    echo Godot not found in common locations.
    echo Please enter the full path to your Godot executable:
    set /p GODOT_PATH="Godot path: "
)

if "%GODOT_PATH%"=="" (
    echo Error: Godot path not specified.
    echo Please run this script again and provide the correct path.
    pause
    exit /b 1
)

echo Found Godot at: %GODOT_PATH%
echo.
echo Opening the TwitchMan Show project...
echo.

REM Open the project with the test scene
%GODOT_PATH% --path "%~dp0" --scene "res://test_conversation_simulation.tscn"

echo.
echo Test environment started!
echo.
echo Instructions:
echo 1. Wait for the scene to load
echo 2. Use the test UI buttons to control the simulation
echo 3. Watch the console output for detailed information
echo 4. Press 'Start Conversation Test' to begin (Fen Barrow & Elias Thorn)
echo.
echo Press any key to exit...
pause >nul
