@echo off
chcp 866 >nul
:: ZapretExtra Manager - запуск, служба, обновления, тесты, конструктор

if "%1"=="admin" goto gotadmin
echo Запрос прав администратора...
powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
exit /b
:gotadmin

setlocal EnableDelayedExpansion
set "ROOT=%~dp0"
set "PRESETS=%~dp0Presets\"
set "BIN=%~dp0bin\"
set "LISTS=%~dp0lists\"
set "LOCAL_VER=1.10.3"
set "EXTRA_VER=1.00"
set "empty=0"
title ZapretExtra v%EXTRA_VER% Manager

:menu
cls
call :show_strategy
echo.
echo   ================= ZapretExtra v%EXTRA_VER% =================
echo   Версия базы: %LOCAL_VER%   Служба: !CUR_STRAT!
echo   --------------------------------------------------
echo.
echo   --- Запуск ---
echo   1. Запустить пресет (временно, до нажатия клавиши)
echo   2. Установить пресет как службу (автозапуск для всех)
echo   3. Удалить службу
echo   4. Статус
echo.
echo   --- Обновления и тесты ---
echo   5. Проверить обновления (пресеты авторов + версия)
echo   6. Тесты стратегий
echo   7. Собрать свой пресет (конструктор)
echo.
echo   --- Настройки ---
echo   8. Настройки (Game Filter / IPSet / прочее)
echo   9. Расширенное меню (service.bat)
echo.
echo   0. Выход
echo.
set "mchoice="
set /p "mchoice=Выберите пункт (0-9): "
if "%mchoice%"=="" (
    set /a empty+=1
    if !empty! GEQ 5 exit /b
    goto menu
)
set "empty=0"
if "%mchoice%"=="1" goto run_preset
if "%mchoice%"=="2" goto install_preset
if "%mchoice%"=="3" goto remove_service
if "%mchoice%"=="4" goto status_m
if "%mchoice%"=="5" goto updates_m
if "%mchoice%"=="6" goto tests_m
if "%mchoice%"=="7" goto builder_m
if "%mchoice%"=="8" goto settings_m
if "%mchoice%"=="9" goto advanced_m
if "%mchoice%"=="0" exit /b
goto menu


:: ---------- выбор пресета ----------
:pick_preset
set "cnt=0"
for /d %%D in ("%PRESETS%*") do (
    set "an=%%~nxD"
    for %%F in ("%%D\*.bat") do (
        set /a cnt+=1
        set "file!cnt!=%%~fF"
        set "auth!cnt!=!an!"
    )
)
if !cnt! EQU 0 (
    echo Пресеты не найдены в папке Presets.
    pause
    goto menu
)
echo.
echo   Доступные пресеты:
for /l %%N in (1,1,!cnt!) do (
    for %%F in ("!file%%N!") do echo   %%N. !auth%%N! \ %%~nxF
)
echo   0. Назад
echo.
set "pchoice="
set /p "pchoice=Номер пресета: "
if "%pchoice%"=="0" goto menu
echo %pchoice% | findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Неверный ввод.
    pause
    goto menu
)
if %pchoice% LSS 1 goto pick_bad
if %pchoice% GTR !cnt! goto pick_bad
set "PICKED=!file%pchoice%!"
for %%F in ("!PICKED!") do set "PDISP=!auth%pchoice%! \ %%~nxF"
set "REL=!PICKED:*Presets\=!"
exit /b
:pick_bad
echo Нет пресета с таким номером.
pause
goto menu


:: ---------- 1. запуск ----------
:run_preset
call :pick_preset
sc query zapret | findstr /i "RUNNING" >nul
if not errorlevel 1 (
    echo ВНИМАНИЕ: служба zapret запущена. Временный запуск может конфликтовать.
    set "cc="
    set /p "cc=Продолжить? (Y/N, по умолчанию N): "
    if /i not "!cc!"=="Y" goto menu
)
echo.
echo Запуск пресета: !PDISP!
call "!PICKED!"
echo.
echo Обход запущен. Нажмите любую клавишу, чтобы остановить...
pause >nul
taskkill /IM winws.exe /F >nul 2>&1
echo Обход остановлен.
pause
goto menu


:: ---------- 2. установка службой ----------
:install_preset
call :pick_preset
call :load_gamevars
echo.
echo Установка пресета: !PDISP!
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="
for /f "tokens=*" %%a in ('type "!PICKED!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"
    call set "line=!line!"
    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )
    if !capture!==1 (
        if not defined args (
            set "line=!line:*winws.exe"=!"
        )
        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"
            if not "!arg!"=="^" if not "!arg!"=="^^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )
                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"
                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%ROOT%!arg:~1!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%ROOT%!arg!\!QUOTE!"
                    )
                )
                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )
                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs!==2 (
                    set "mergeargs=1"
                )
            )
        )
        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)
call :tcp_enable
set "ARGS=!args!"
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Итоговые аргументы: !ARGS!
set "SRVCNAME=zapret"
net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!REL!" /f >nul
echo.
echo Служба установлена и запущена: !REL!
pause
goto menu


:: ---------- 3. удаление службы ----------
:remove_service
cls
echo Удаление службы zapret...
sc query "zapret" >nul 2>&1
if not errorlevel 1 (
    net stop zapret
    sc delete zapret
) else (
    echo Служба zapret не установлена.
)
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" >nul
if not errorlevel 1 (
    taskkill /IM winws.exe /F >nul
    echo Процесс winws.exe завершен.
)
sc query "WinDivert" >nul 2>&1
if not errorlevel 1 (
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1
echo Готово.
pause
goto menu


:: ---------- 4. статус ----------
:status_m
cls
call :show_strategy
echo Текущий пресет в службе: !CUR_STRAT!
echo.
sc query "zapret" | findstr /i "STATE" 
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" >nul
if not errorlevel 1 (
    call :PrintGreen "Обход (winws.exe) ЗАПУЩЕН."
) else (
    call :PrintRed "Обход (winws.exe) НЕ запущен."
)
sc query "WinDivert" | findstr /i "STATE"
echo.
pause
goto menu


:: ---------- 5. обновления ----------
:updates_m
cls
echo Проверка обновлений...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%utils\sync-presets.ps1"
echo.
echo Обновление списка AWS...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%update-aws.ps1"
echo.
pause
goto menu


:: ---------- 6. тесты ----------
:tests_m
cls
echo.
echo   ---------- Тесты стратегий ----------
echo   Далее тест сам спросит профиль (Discord/CF/AWS/...), лимиты
echo   времени/пинга и выбор конфигов.
echo.
echo   1. Standard (HTTP, TLS 1.1/1.2/1.3, пинг с потерями)
echo   2. DPI checkers (замирание TCP 16-20)
echo   3. Combined (Standard + DPI за один прогон)
echo.
echo   0. Назад
echo.
set "tchoice="
set /p "tchoice=Тип теста (0-3): "
if "%tchoice%"=="1" set "ZAPRET_TEST_TYPE=standard"
if "%tchoice%"=="2" set "ZAPRET_TEST_TYPE=dpi"
if "%tchoice%"=="3" set "ZAPRET_TEST_TYPE=combined"
if "%tchoice%"=="0" goto menu
if "%tchoice%"=="1" goto tests_go
if "%tchoice%"=="2" goto tests_go
if "%tchoice%"=="3" goto tests_go
goto tests_m
:tests_go
echo Открываю окно тестов в новом окне...
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%utils\test zapret.ps1"
set "ZAPRET_TEST_TYPE="
goto menu


:: ---------- 7. конструктор ----------
:builder_m
call "%ROOT%BUILD-CUSTOM-PRESET.bat"
goto menu


:: ---------- 8. настройки ----------
:settings_m
cls
call :game_status
call :ipset_status
if exist "%ROOT%utils\check_updates.enabled" (
    set "UPD=включена"
) else (
    set "UPD=выключена"
)
echo.
echo   ---------- Настройки ----------
echo   Game Filter: !GF_STAT!
echo   IPSet: !IPSET_STAT!
echo   Проверка обновлений при запуске: !UPD!
echo.
echo   1. Game Filter вкл/выкл
echo   2. IPSet режим (loaded/none/any)
echo   3. Проверка обновлений вкл/выкл
echo   4. Обновить AWS-список сейчас
echo.
echo   0. Назад
echo.
set "schoice="
set /p "schoice=Выберите пункт: "
if "%schoice%"=="1" goto game_toggle
if "%schoice%"=="2" goto ipset_cycle
if "%schoice%"=="3" goto upd_toggle
if "%schoice%"=="4" goto aws_now
if "%schoice%"=="0" goto menu
goto settings_m

:game_toggle
if "!GF_STAT!"=="выключен" (
    echo Включаю Game Filter (TCP+UDP 1024-65535)...
    >"%ROOT%utils\game_filter.enabled" (
        echo mode=all
        echo tcp=1024-65535
        echo udp=1024-65535
    )
) else (
    echo Выключаю Game Filter...
    del /f /q "%ROOT%utils\game_filter.enabled" >nul 2>&1
)
echo Нужен перезапуск обхода, чтобы применить.
pause
goto settings_m

:ipset_cycle
cls
echo Текущий режим IPSet: !IPSET_STAT!
echo.
echo   1. loaded (список из бэкапа/репозитория)
echo   2. none (только hostlist-фильтры)
echo   3. any (фильтровать все IP)
echo   0. Назад
set "ichoice="
set /p "ichoice=Выберите режим: "
if "%ichoice%"=="1" goto ipset_loaded
if "%ichoice%"=="2" goto ipset_none
if "%ichoice%"=="3" goto ipset_any
if "%ichoice%"=="0" goto settings_m
goto ipset_cycle

:ipset_loaded
if exist "%LISTS%ipsets\all.txt.backup" (
    del /f /q "%LISTS%ipsets\all.txt" >nul 2>&1
    ren "%LISTS%ipsets\all.txt.backup" "all.txt"
    echo Режим loaded восстановлен из бэкапа.
) else (
    echo Скачиваю список из репозитория...
    powershell -NoProfile -Command "$u='https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt'; $o='%LISTS%ipsets\all.txt'; (Invoke-WebRequest -Uri $u -TimeoutSec 15 -UseBasicParsing).Content | Out-File -FilePath $o -Encoding UTF8"
    echo Список обновлен.
)
pause
goto settings_m

:ipset_none
if exist "%LISTS%ipsets\all.txt" (
    findstr /C:"203.0.113.113/32" "%LISTS%ipsets\all.txt" >nul
    if errorlevel 1 (
        if exist "%LISTS%ipsets\all.txt.backup" del /f /q "%LISTS%ipsets\all.txt.backup"
        ren "%LISTS%ipsets\all.txt" "all.txt.backup"
    )
)
echo 203.0.113.113/32>"%LISTS%ipsets\all.txt"
echo Режим none включен.
pause
goto settings_m

:ipset_any
for /f %%i in ('type "%LISTS%ipsets\all.txt" 2^>nul ^| find /c /v ""') do set "lc=%%i"
if not "!lc!"=="0" (
    if exist "%LISTS%ipsets\all.txt.backup" del /f /q "%LISTS%ipsets\all.txt.backup"
    ren "%LISTS%ipsets\all.txt" "all.txt.backup"
)
type nul > "%LISTS%ipsets\all.txt"
echo Режим any включен. ВНИМАНИЕ: может ломать обычные сайты.
pause
goto settings_m

:upd_toggle
if exist "%ROOT%utils\check_updates.enabled" (
    del /f /q "%ROOT%utils\check_updates.enabled"
    echo Проверка обновлений выключена.
) else (
    echo ENABLED>"%ROOT%utils\check_updates.enabled"
    echo Проверка обновлений включена.
)
pause
goto settings_m

:aws_now
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%update-aws.ps1"
pause
goto settings_m


:: ---------- 9. расширенное меню ----------
:advanced_m
start "" "%ROOT%service.bat"
goto menu


:: ================= helpers =================
:show_strategy
set "CUR_STRAT=не установлена"
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do set "CUR_STRAT=%%B"
exit /b

:game_status
set "GF_STAT=выключен"
if exist "%ROOT%utils\game_filter.enabled" (
    set "GF_STAT=включен"
    for /f "usebackq tokens=1,* delims==" %%A in ("%ROOT%utils\game_filter.enabled") do (
        if /i "%%A"=="mode" set "GF_STAT=включен (%%B)"
    )
)
exit /b

:ipset_status
set "IPSET_STAT=неизвестно"
set "listFile=%LISTS%ipsets\all.txt"
set "lineCount=0"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"
if "!lineCount!"=="0" (
    set "IPSET_STAT=any"
) else (
    findstr /C:"203.0.113.113/32" "%listFile%" >nul
    if not errorlevel 1 (
        set "IPSET_STAT=none"
    ) else (
        set "IPSET_STAT=loaded"
    )
)
exit /b

:load_gamevars
set "GameFilterTCP=12"
set "GameFilterUDP=12"
set "gffile=%ROOT%utils\game_filter.enabled"
if not exist "%gffile%" exit /b
set "gfmode=disabled"
set "gftcp=1024-65535"
set "gfudp=1024-65535"
for /f "usebackq tokens=1,* delims==" %%A in ("%gffile%") do (
    if /i "%%A"=="mode" set "gfmode=%%B"
    if /i "%%A"=="tcp" set "gftcp=%%B"
    if /i "%%A"=="udp" set "gfudp=%%B"
)
if /i "%gfmode%"=="all" (
    set "GameFilterTCP=%gftcp%"
    set "GameFilterUDP=%gfudp%"
) else if /i "%gfmode%"=="tcp" (
    set "GameFilterTCP=%gftcp%"
) else if /i "%gfmode%"=="udp" (
    set "GameFilterUDP=%gfudp%"
)
exit /b

:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" >nul
if errorlevel 1 netsh interface tcp set global timestamps=enabled >nul 2>&1
exit /b

:PrintGreen
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b
