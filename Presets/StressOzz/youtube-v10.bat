@echo off
chcp 65001 > nul
:: StressOzz youtube-v10 (StressOzz/Zapret-Manager, adapted for winws)

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_user_lists
echo:

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: youtube-v10 (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%domains\google.txt" --dpi-desync=multisplit --dpi-desync-split-pos=1,2 --dpi-desync-split-seqovl=4 --dpi-desync-split-seqovl-pattern="%BIN%tls_clienthello\tls_clienthello_www_google_com.bin" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com
