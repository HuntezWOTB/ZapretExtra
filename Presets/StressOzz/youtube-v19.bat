@echo off
chcp 65001 > nul
:: StressOzz youtube-v19 (StressOzz/Zapret-Manager, adapted for winws)

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_user_lists
echo:

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: youtube-v19 (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%domains\google.txt" --dpi-desync=fake,multisplit --dpi-desync-fake-tls=0x00000000 --dpi-desync-fake-tls=^! --dpi-desync-split-pos=1,midsld --dpi-desync-repeats=2 --dpi-desync-fooling=badseq --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com


