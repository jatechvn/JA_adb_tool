@echo off
setlocal enabledelayedexpansion

:: Thiet lap file Log tai thu muc Pictures
set "log_file=%USERPROFILE%\Pictures\adb_copy_log.txt"

:CHOOSE_DEVICE
cls
echo ==========================================
echo       BUOC 1: KIEM TRA THIET BI ADB
echo ==========================================

for /L %%k in (1,1,10) do (
    set "dev%%k="
    set "display_name%%k="
)

set i=0
for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" (
        set /a i+=1
        set "dev!i!=%%a"
        
        echo Dang lay thong tin thiet bi !i!...
        
        :: Lay Model va Name
        set "m_model=Unknown"
        for /f "tokens=*" %%m in ('adb -s %%a shell getprop ro.product.model 2^>nul') do set "m_model=%%m"
        set "m_name=Unknown"
        for /f "tokens=*" %%n in ('adb -s %%a shell getprop ro.product.name 2^>nul') do set "m_name=%%n"
        
        :: DINH DANG MOI: Ten (Model: ModelName - SN: SerialNumber )
        set "display_name!i!=!m_name! (Model: !m_model! - SN: %%a )"
    ) else if "%%b" neq "" (
        set /a i+=1
        set "dev!i!=%%a"
        set "display_name!i!=%%a (Trang thai: %%b )"
    )
)

if %i%==0 (
    echo Khong tim thay thiet bi! & pause & goto CHOOSE_DEVICE
)

if %i%==1 (
    set "selected_device=%dev1%"
    set "selected_display=!display_name1!"
    echo Phat hien: !selected_display!
    timeout /t 1 >nul
    goto CHOOSE_FOLDER
)

echo Tim thay %i% thiet bi:
for /L %%k in (1,1,%i%) do (
    echo %%k. !display_name%%k!
)
echo.
set "keys="
for /L %%k in (1,1,%i%) do set "keys=!keys!%%k"
choice /c %keys% /n /m "Chon thiet bi (bam so): "
set dev_choice=%errorlevel%
set "selected_device=!dev%dev_choice%!"
set "selected_display=!display_name%dev_choice%!"

:CHOOSE_FOLDER
cls
echo ==========================================
echo    BUOC 2: CHON THU MUC HOAC SO LUONG
echo    Device: %selected_display%
echo ==========================================
echo [A]. Copy 10 anh MOI NHAT
echo [B]. Copy 20 anh MOI NHAT
echo [C]. Nhap so luong anh can copy
echo [S]. QUAY LAI chon thiet bi
echo ------------------------------------------

set j=0
for /f "tokens=*" %%f in ('adb -s %selected_device% shell "ls -d /storage/emulated/0/DCIM/*/ 2>/dev/null"') do (
    set /a j+=1
    for /f "tokens=5 delims=/" %%g in ("%%f") do set "folder_name=%%g"
    set "folder!j!=!folder_name!"
    echo !j!. !folder_name!
)

echo.
set "f_keys=ABCS"
for /L %%k in (1,1,%j%) do set "f_keys=!f_keys!%%k"

choice /c %f_keys% /n /m "Bam phim (A/B/C/S hoac so) de chon: "
set res=%errorlevel%

if %res%==1 (set "count=10" & goto EXECUTE_LATEST)
if %res%==2 (set "count=20" & goto EXECUTE_LATEST)
if %res%==3 (goto INPUT_COUNT)
if %res%==4 (goto CHOOSE_DEVICE)

set /a folder_idx=%res%-4
set "selected_folder=!folder%folder_idx%!"
goto EXECUTE_FOLDER

:INPUT_COUNT
echo.
set /p count="Nhap so luong anh can copy: "
if "!count!"=="" set "count=10"
goto EXECUTE_LATEST

:EXECUTE_LATEST
set "target_pc=%USERPROFILE%\Pictures\Latest_!count!_Files"
set "mode_desc=!count! file moi nhat"
goto START_PULL

:EXECUTE_FOLDER
set "target_pc=%USERPROFILE%\Pictures\!selected_folder!"
set "mode_desc=Thu muc !selected_folder!"
goto START_PULL

:START_PULL
echo.
echo Dang thuc hien...
if not exist "!target_pc!" mkdir "!target_pc!"

:: Ghi Log
echo [%DATE% %TIME%] Device: %selected_display% >> "%log_file%"
echo Che do: %mode_desc% >> "%log_file%"
echo Luu tai: !target_pc! >> "%log_file%"
echo Danh sach file: >> "%log_file%"

if "%mode_desc:~0,7%"=="Thu muc" (
    adb -s %selected_device% pull "/storage/emulated/0/DCIM/!selected_folder!/." "!target_pc!" >> "%log_file%" 2>&1
) else (
    for /f "tokens=*" %%a in ('adb -s %selected_device% shell "sh -c 'find /storage/emulated/0/DCIM/ -type f | grep -v \"/\.\" | xargs ls -t | head -n !count! '"') do (
        if not "%%a"=="" (
            echo Dang copy: %%a
            echo %%a >> "%log_file%"
            adb -s %selected_device% pull "%%a" "!target_pc!"
        )
    )
)

echo ------------------------------------------ >> "%log_file%"
goto FINISH

:FINISH
echo.
echo ==========================================
echo [HOAN THANH!] 
echo Log da luu tai: Pictures\adb_copy_log.txt
echo ==========================================
explorer "!target_pc!"
timeout /t 5
exit