@echo off
cd /d %~dp0
echo [CLEAN] Cleaning Flutter project build files...
call flutter clean
pause
