ZapretExtra — интеграция CloudFlare + Amazon в пресеты 1.10.3
==============================================================
(историческая справка; актуальная раскладка списков — README_LISTS.txt)

База: zapret-discord-youtube-1.10.3 (bin/winws.exe, service.bat, utils).
Из zapret-aws-cloudflare-2- добавлены IP-диапазоны CloudFlare и Amazon AWS
(сейчас lists\ipsets\cloudflare.txt и lists\ipsets\amazon.txt), скрипт
update-aws.ps1, а домены CloudFlare/AWS/YouTube разложены по
lists\domains\*.txt (см. README_LISTS.txt).

В каждый из 22 пресетов Flowseal встроено:
  1. Блок автообновления AWS-листа при запуске.
  2. WFP расширен на 444-65535 в TCP и UDP.
  3. 4 фильтра перед GameFilter-блоками (стратегия — как у ipset-all
     в том же пресете для Cloudflare; fake+autottl для AWS),
     все с учетом exclude-листов.
Пресеты StressOzz (v1-v10, youtube-v01-v27) оставлены как у автора.
