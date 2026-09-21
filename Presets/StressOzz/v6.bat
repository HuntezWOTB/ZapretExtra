@echo off
chcp 65001 > nul
:: StressOzz v6 (StressOzz/Zapret-Manager, adapted for winws)

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_game_filter
call "%ROOT%service.bat" load_user_lists
echo:

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: v6 (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443,2053,2083,2087,2096,8443,%GameFilterTCP% --wf-udp=19294-19344,50000-50100,%GameFilterUDP% ^
--new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord="%BIN%stun.bin" --dpi-desync-fake-stun="%BIN%stun.bin" --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=multisplit --dpi-desync-split-seqovl=652 --dpi-desync-split-pos=2 --dpi-desync-split-seqovl-pattern="%BIN%tls_clienthello\tls_clienthello_www_google_com.bin" --new ^
--filter-tcp=443 --hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --dpi-desync=hostfakesplit --dpi-desync-hostfakesplit-mod=host=i2.photo.2gis.com --dpi-desync-hostfakesplit-midhost=host-2 --dpi-desync-split-seqovl=726 --dpi-desync-fooling=badsum,badseq --dpi-desync-badseq-increment=0 --new ^
--new --filter-udp=%GameFilterUDP% --dpi-desync=fake --dpi-desync-cutoff=d2 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp="%BIN%stun.bin"
