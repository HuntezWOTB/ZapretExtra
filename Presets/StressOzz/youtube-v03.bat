@echo off
chcp 65001 > nul
:: StressOzz youtube-v03 (StressOzz/Zapret-Manager, adapted for winws)

cd /d "%~dp0"
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%service.bat" status_zapret
call "%ROOT%service.bat" check_updates
call "%ROOT%service.bat" load_user_lists
echo:

set "BIN=%ROOT%bin\"
set "LISTS=%ROOT%lists\"
cd /d %BIN%

start "zapret: youtube-v03 (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%domains\google.txt" --dpi-desync=fake,multisplit --dpi-desync-split-pos=2,sld --dpi-desync-fake-tls=0x0F0F0F0F --dpi-desync-fake-tls="%BIN%tls_clienthello\tls_clienthello_www_google_com.bin" --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ggpht.com --dpi-desync-split-seqovl=620 --dpi-desync-split-seqovl-pattern="%BIN%tls_clienthello\tls_clienthello_www_google_com.bin" --dpi-desync-fooling=badsum,badseq
