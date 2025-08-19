# TwitchMan Conversation Test Environment Launcher
# PowerShell script to start the conversation test environment

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TwitchMan Conversation Test Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you start the conversation test environment." -ForegroundColor White
Write-Host ""
Write-Host "Prerequisites:" -ForegroundColor Yellow
Write-Host "1. LM Studio must be running with your model loaded" -ForegroundColor White
Write-Host "2. Local server must be started on http://localhost:1234" -ForegroundColor White
Write-Host "3. Godot must be installed and accessible" -ForegroundColor White
Write-Host ""

# Check if LM Studio is running
Write-Host "Checking LM Studio status..." -ForegroundColor Blue
try {
    $response = Invoke-WebRequest -Uri "http://localhost:1234/v1/models" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ LM Studio is running and accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ LM Studio is not accessible at http://localhost:1234" -ForegroundColor Red
    Write-Host "  Please ensure LM Studio is running and the local server is started" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue anyway, or Ctrl+C to exit"
}

Write-Host ""
Write-Host "Starting Godot with the test scene..." -ForegroundColor Blue
Write-Host ""

# Try to find Godot in common locations
$godotPath = $null

$possiblePaths = @(
    "C:\Program Files\Godot\Godot_v4.x.x-stable_win64.exe",
    "C:\Program Files (x86)\Godot\Godot_v4.x.x-stable_win64.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Godot\Godot_v4.x.x-stable_win64.exe",
    "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.x.x-stable_win64.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $godotPath = $path
        break
    }
}

# Also check for any Godot executable in common locations
if (-not $godotPath) {
    $godotDirs = @(
        "C:\Program Files\Godot",
        "C:\Program Files (x86)\Godot",
        "$env:USERPROFILE\AppData\Local\Programs\Godot",
        "$env:LOCALAPPDATA\Programs\Godot"
    )
    
    foreach ($dir in $godotDirs) {
        if (Test-Path $dir) {
            $godotExe = Get-ChildItem -Path $dir -Name "Godot*.exe" | Select-Object -First 1
            if ($godotExe) {
                $godotPath = Join-Path $dir $godotExe
                break
            }
        }
    }
}

if (-not $godotPath) {
    Write-Host "Godot not found in common locations." -ForegroundColor Red
    Write-Host "Please enter the full path to your Godot executable:" -ForegroundColor Yellow
    $godotPath = Read-Host "Godot path"
}

if (-not $godotPath -or -not (Test-Path $godotPath)) {
    Write-Host "Error: Invalid Godot path specified." -ForegroundColor Red
    Write-Host "Please run this script again and provide the correct path." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found Godot at: $godotPath" -ForegroundColor Green
Write-Host ""
Write-Host "Opening the TwitchMan Show project..." -ForegroundColor Blue
Write-Host ""

# Get the current script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Open the project with the test scene
try {
    Start-Process -FilePath $godotPath -ArgumentList "--path", "`"$scriptDir`"", "--scene", "res://test_conversation_simulation.tscn"
    Write-Host "✓ Godot launched successfully!" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to launch Godot: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Test environment started!" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Wait for the scene to load" -ForegroundColor White
Write-Host "2. Use the test UI buttons to control the simulation" -ForegroundColor White
Write-Host "3. Watch the console output for detailed information" -ForegroundColor White
Write-Host "4. Press 'Start Conversation Test' to begin" -ForegroundColor White
Write-Host ""
Write-Host "The test environment will:" -ForegroundColor Cyan
Write-Host "- Check LLM connectivity" -ForegroundColor White
Write-Host "- Create a conversation between Fen Barrow and Elias Thorn" -ForegroundColor White
Write-Host "- Simulate 10 turns of dialogue" -ForegroundColor White
Write-Host "- Track conversation flow and mood changes" -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to exit this launcher..." -ForegroundColor Gray
Read-Host
