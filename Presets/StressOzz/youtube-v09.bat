@echo off
chcp 65001 > nul
:: StressOzz youtube-v09 (StressOzz/Zapret-Manager, adapted for winws)

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_user_lists
echo:

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: youtube-v09 (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%domains\google.txt" --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=2 --dpi-desync=multidisorder --dpi-desync-split-pos=1,midsld --dpi-desync-fake-quic="%BIN%quic_initial\quic_initial_www_google_com.bin"


