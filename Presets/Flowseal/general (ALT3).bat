@echo off
chcp 65001 > nul
:: 65001 - UTF-8

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_game_filter
call "%ROOT%service.bat" load_user_lists
echo:
:: === AWS/CF: auto-update Amazon IP list ===
set "AWS_LIST=%ROOT%lists\ipsets\amazon.txt"
set "AWS_BEFORE=0"
if exist "%AWS_LIST%" (
    for /f %%A in ('find /c /v "" ^< "%AWS_LIST%"') do set AWS_BEFORE=%%A
)
echo [INFO] AWS list: %AWS_BEFORE% entries, updating...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%update-aws.ps1"
if %ERRORLEVEL% neq 0 (
    echo [WARN] AWS update failed, using cached list.
) else (
    set "AWS_AFTER=0"
    if exist "%AWS_LIST%" (
        for /f %%A in ('find /c /v "" ^< "%AWS_LIST%"') do set AWS_AFTER=%%A
    )
    echo [INFO] AWS list updated: %AWS_BEFORE% -^> %AWS_AFTER%
    echo.
)
set "AWS_BEFORE="
set "AWS_AFTER="
:: === end AWS update ===

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: %~n0" /min "%BIN%winws.exe" --wf-tcp=80,443,2053,2083,2087,2096,8443,444-65535,%GameFilterTCP% --wf-udp=443,19294-19344,50000-50100,444-65535,%GameFilterUDP% ^
--filter-udp=443 --hostlist="%LISTS%domains\general.txt" --hostlist="%LISTS%domains\telegram.txt" --hostlist="%LISTS%domains\twitter.txt" --hostlist="%LISTS%domains\facebook.txt" --hostlist="%LISTS%domains\discord.txt" --hostlist="%LISTS%domains\google.txt" --hostlist="%LISTS%domains\cloudflare.txt" --hostlist="%LISTS%domains\amazon.txt" --hostlist="%LISTS%domains\instagram.txt" --hostlist="%LISTS%domains\general-user.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial\quic_initial_www_google_com.bin" --new ^
--filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord="%BIN%ACTIVE_DISCORD_UDP.bin" --dpi-desync-fake-stun="%BIN%ACTIVE_DISCORD_UDP.bin" --dpi-desync-repeats=6 --new ^
--filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-hostfakesplit-mod=host=www.google.com,altorder=1 --dpi-desync-fooling=ts --new ^
--filter-tcp=443 --hostlist="%LISTS%domains\google.txt" --ip-id=zero --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-hostfakesplit-mod=host=www.google.com,altorder=1 --dpi-desync-fooling=ts --new ^
--filter-tcp=80,443 --hostlist="%LISTS%domains\general.txt" --hostlist="%LISTS%domains\telegram.txt" --hostlist="%LISTS%domains\twitter.txt" --hostlist="%LISTS%domains\facebook.txt" --hostlist="%LISTS%domains\discord.txt" --hostlist="%LISTS%domains\google.txt" --hostlist="%LISTS%domains\cloudflare.txt" --hostlist="%LISTS%domains\amazon.txt" --hostlist="%LISTS%domains\instagram.txt" --hostlist="%LISTS%domains\general-user.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BIN%tls_clienthello\tls_clienthello_max_ru.bin" --new ^
--filter-udp=443 --ipset="%LISTS%ipsets\all.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial\quic_initial_www_google_com.bin" --new ^
--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\all.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BIN%tls_clienthello\tls_clienthello_max_ru.bin" --new ^
--filter-udp=443 --ipset="%LISTS%ipsets\cloudflare.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial\quic_initial_www_google_com.bin" --new ^
--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\cloudflare.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BIN%tls_clienthello\tls_clienthello_max_ru.bin" --new ^
--filter-udp=444-65535 --ipset="%LISTS%ipsets\amazon.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=10 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp="%BIN%quic_initial\quic_initial_www_google_com.bin" --dpi-desync-cutoff=n2 --new ^
--filter-tcp=444-65535 --ipset="%LISTS%ipsets\amazon.txt" --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --new ^
--filter-tcp=%GameFilterTCP% --ipset="%LISTS%ipsets\all.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake,hostfakesplit --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n4 --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http="%BIN%tls_clienthello\tls_clienthello_max_ru.bin" --dpi-desync-fake-unknown="%BIN%tls_clienthello\tls_clienthello_max_ru.bin" --new ^
--filter-udp=%GameFilterUDP% --ipset="%LISTS%ipsets\all.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=10 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp="%BIN%ACTIVE_GAME_UDP.bin" --dpi-desync-cutoff=n4






