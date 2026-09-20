Стратегии StressOzz (сборка Zapret-Manager)
=============================================
Источник: https://github.com/StressOzz/Zapret-Manager
  - v1..v10 — из Strategies.md (nfqws-блоки + Discord + game).
  - youtube-v01..v27 — из Strategies_For_Youtube.md (по list-google.txt).

Файлы собраны конвертером utils\convert-stressozz.ps1 (запуск вручную
для обновления с GitHub; пункт 5 менеджера делает это автоматически).
Пути фейков пересчитаны на локальные bin\:
  stun.bin, tls_clienthello_www_google_com.bin,
  tls_clienthello_4pda_to.bin (вместо авторского 4pda.bin),
  tls_clienthello_vk_com.bin + gosuslugi_ru.bin (сгенерированы
  utils\make-fake-bin.ps1), quic_initial_www_google_com.bin.
Вместо zapret-hosts-user-exclude.txt используются domains\exclude.txt +
domains\exclude-user.txt, вместо zapret-hosts-google.txt — domains\google.txt.

Замечания (стратегии оставлены как у автора, дословно):
  - v5, Yv05, Yv17, Yv23 содержат режим fakeddisorder — winws может его
    не знать; тесты покажут (статус "failed to start" = не завелся).
  - Yv06 содержит --dpi-desync-autottl 2:2-12 (nfqws-синтаксис).
  - Yv17 содержит --dup* опции (только nfqws).
  - Game-блок автора (cutoff d2) подключен через %GameFilterUDP%.
