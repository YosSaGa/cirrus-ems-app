@echo off
title Cirrus EMS - Cloud API & Android Emulator Launcher
chcp 65001 >nul

echo ============================================================
echo   Cirrus EMS - Cloud API (api.cirrusmarine.site) + Emulator
echo ============================================================
echo.

:: 1. Verify live Cloud EMS API health
echo [1/3] Checking Cloud EMS API (https://api.cirrusmarine.site/api/v1/ems)...
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Uri 'https://api.cirrusmarine.site/api/v1/ems/health' -TimeoutSec 5; Write-Host ('      API Online - database: ' + $r.database) -ForegroundColor Green; exit 0 } catch { Write-Host '      Warning: Could not reach api.cirrusmarine.site (check internet)' -ForegroundColor Yellow; exit 1 }"

:: 2. Clear any stale AVD lock files (ignore if already running)
if exist "%USERPROFILE%\.android\avd\Pixel_10_Pro_XL_API_35.avd\*.lock" (
    del /f /q "%USERPROFILE%\.android\avd\Pixel_10_Pro_XL_API_35.avd\*.lock" >nul 2>&1
)

:: 3. Launch auto-opener in background to start Cirrus EMS app once emulator boots
echo [2/3] Launching Android Emulator ^(Pixel_10_Pro_XL_API_35^)...
start "" /min cmd /c "powershell -NoProfile -Command ""$adb = '$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe'; & $adb -s emulator-5554 wait-for-device; for ($i=0; $i -lt 60; $i++) { if (((& $adb -s emulator-5554 shell getprop sys.boot_completed 2>$null) -join '').Trim() -eq '1') { break }; Start-Sleep -Seconds 2 }; Start-Sleep -Seconds 3; & $adb -s emulator-5554 shell am start -n com.cirrusgroup.ems/.MainActivity"""

echo [3/3] Opening Emulator window... (Please wait ~20-30s for boot; Cirrus EMS will open automatically)
echo       Keep this window minimized while using the emulator.
echo.
"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_10_Pro_XL_API_35 -no-snapshot-load

echo.
echo Emulator closed.
pause
