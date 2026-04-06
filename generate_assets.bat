@echo off
REM ============================================
REM Mint Asset Generator Helper Script
REM ============================================
REM This script helps you generate PNG assets
REM from the SVG files for your Flutter app.
REM ============================================

echo.
echo ============================================
echo    Mint Transaction Tracker - Asset Setup
echo ============================================
echo.

REM Check if Python is available (for svglib option)
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] Python found
    echo.
    echo Installing SVG to PNG conversion library...
    pip install svglib reportlab pillow
    echo.
    echo Converting launcher icon...
    python -c "from svglib.svglib import svg2rlg; from reportlab.graphics import renderPM; drawing = svg2rlg('assets/icon/mint_logo.svg'); renderPM.drawToFile(drawing, 'assets/icon/mint_logo.png', fmt='PNG', dpi=300)"
    echo.
    echo Converting splash screen...
    python -c "from svglib.svglib import svg2rlg; from reportlab.graphics import renderPM; drawing = svg2rlg('assets/images/splash_screen.svg'); renderPM.drawToFile(drawing, 'assets/images/splash.png', fmt='PNG', dpi=300)"
    echo.
    echo [SUCCESS] PNG files generated!
) else (
    echo [INFO] Python not found. Manual conversion required.
    echo.
    echo Please follow these steps:
    echo.
    echo 1. Open assets/generate_assets.html in your browser
    echo 2. Right-click each image and select "Save Image As"
    echo 3. Save as:
    echo    - assets/icon/mint_logo.png (512x512)
    echo    - assets/images/splash.png (1080x1920)
    echo.
    echo OR use an online converter:
    echo    https://cloudconvert.com/svg-to-png
    echo.
)

echo.
echo ============================================
echo Next Steps:
echo ============================================
echo.
echo 1. Ensure PNG files are in place
echo 2. Run: flutter pub get
echo 3. Run: flutter pub run flutter_launcher_icons
echo 4. Run: flutter pub run flutter_native_splash:create
echo.
echo ============================================
echo.
pause
