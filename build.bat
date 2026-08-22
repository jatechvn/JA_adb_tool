@echo off
setlocal EnableExtensions
cd /d %~dp0

for /f "tokens=2 delims=:" %%A in ('findstr /b /c:"version:" pubspec.yaml') do set "APP_VERSION=%%A"
set "APP_VERSION=%APP_VERSION: =%"
for /f "tokens=1 delims=+" %%A in ("%APP_VERSION%") do set "APP_VERSION=%%A"
set "PACKAGE_NAME=JA_adb_tool_v%APP_VERSION%_Windows_x64"
set "REL=build\windows\x64\runner\Release"

echo [PREPARE] Stopping active JA ADB Tool, ADB, and Scrcpy processes...
taskkill /f /im ja_adb_tool.exe >nul 2>&1
taskkill /f /im adb.exe >nul 2>&1
taskkill /f /im scrcpy.exe >nul 2>&1

echo [BUILD] Compiling JA ADB Tool v%APP_VERSION% in Release mode...
call flutter build windows --release
if errorlevel 1 (
    echo [ERROR] Build failed!
    exit /b %errorlevel%
)

echo [BACKUP] Preserving previous release output...
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "BACKUP_STAMP=%%A"
if exist "dist" (
    if not exist "backup" mkdir "backup"
    move "dist" "backup\dist_%BACKUP_STAMP%" >nul
)
if exist "dist_pack" (
    if not exist "backup" mkdir "backup"
    move "dist_pack" "backup\dist_pack_%BACKUP_STAMP%" >nul
)
mkdir "dist"

echo [SECURITY] Removing runtime data from the Release directory...
if exist "%REL%\config.json" del /f /q "%REL%\config.json"
if exist "%REL%\config.ini" del /f /q "%REL%\config.ini"
if exist "%REL%\logs" rmdir /s /q "%REL%\logs"

echo [DIST] Copying Release output and bundled tools...
xcopy /e /i /y /q "%REL%\*" "dist\" >nul
if exist "bin" xcopy /e /i /y /q "bin" "dist\bin\" >nul
if exist "README.md" copy /y "README.md" "dist\" >nul
if exist "CHANGELOG.md" copy /y "CHANGELOG.md" "dist\" >nul
if exist "USERGUIDE.md" copy /y "USERGUIDE.md" "dist\" >nul
if exist "ABOUT.txt" copy /y "ABOUT.txt" "dist\" >nul
if exist "RELEASE_NOTES.md" copy /y "RELEASE_NOTES.md" "dist\" >nul
if exist "debug.bat" copy /y "debug.bat" "dist\" >nul
if exist "LICENSE" copy /y "LICENSE" "dist\" >nul

echo [PACKAGE] Creating parent-folder ZIP: %PACKAGE_NAME%.zip
mkdir "dist_pack\%PACKAGE_NAME%"
xcopy /e /i /y /q "dist\*" "dist_pack\%PACKAGE_NAME%\" >nul
powershell -NoProfile -Command "Compress-Archive -Path 'dist_pack\%PACKAGE_NAME%' -DestinationPath 'dist\%PACKAGE_NAME%.zip' -Force"
if errorlevel 1 (
    echo [ERROR] ZIP packaging failed!
    exit /b %errorlevel%
)
rmdir /s /q "dist_pack"

echo [SUCCESS] Release package created: dist\%PACKAGE_NAME%.zip
pause
