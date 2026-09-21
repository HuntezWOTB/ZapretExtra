@echo off
chcp 866 > nul
title Конвертер пресета под роутер
:: ZapretExtra -> OpenWRT (пункт 12 менеджера тоже ведет сюда)
cd /d "%~dp0"
echo Выбор пресета для роутера...
echo Откроется окно проводника - выбери .bat пресет.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\convert-openwrt.ps1"
echo Готово. Файл *_openwrt.txt лежит рядом с пресетом.
echo Нажми любую клавишу...
pause > nul
