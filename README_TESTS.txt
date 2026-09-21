TESTS v4 — режимы, профили, лимиты, факторы
======================================================
Запуск: service.bat -> 12. Run Tests (админ, без службы zapret).

РЕЖИМ: [1] Standard  [2] DPI checkers  [3] Combined (оба за прогон).
ПРОФИЛЬ (Standard/Combined): [0] All  [1] Discord  [2] CloudFlare (11)
[3] Amazon (11)  [4] Instagram (5)  [5] X/Twitter (10)  [6] YouTube (4)
[7] Telegram (4)  [8] Facebook (4).
Discord-профиль меряет signalling+медиа (войс/экран идут через
одинаковые во всех пресетах UDP L7-фильтры — стратегия там не различается).

ЛИМИТЫ (вопрос перед прогоном, 0 = без лимита; либо env TEST_RESP_LIMIT /
TEST_PING_LIMIT — удобно для службы/автоматизации):
  - ответ дольше N сек (по умолч. 2) -> токен TIMEENDED (как ошибка, отдельно
    считается в аналитике; влияет на best и сборщик минусом к счету);
  - пинг дольше M мс (по умолч. 100) -> SLOW (считается провалом пинга
    везде: аналитика, сборщик).
Лимиты сохраняются в .json/.txt шапку.

ФАКТОРЫ: HTTP OK (HTTP, TLS 1.1/1.2/1.3) + время t=Ns; пинг 4 эха
("12 ms, loss 0%"); замер скорости УБРАН по решению (шумный).
Приоритет: больше OK -> меньше ERROR(+TIMEENDED) -> живой пинг ->
меньше loss% -> (сборщик) меньше DPI-блокировок.

ВЫХОД: utils\"test results"\test_results_<дата>.txt + .json
(testType, profile, respLimit, pingLimit, best, bestDpi).
BUILD-CUSTOM-PRESET.bat ест standard/combined, dpi-записи идут только
в штраф конфига (frankenstein собирается с учетом DPI-проверок).
Детали сборки — README_CUSTOM_BUILDER.txt.

Свои мишени — в utils\targets.txt (ключ одним словом, профиль цепляет
по префиксу). Свои фейки — utils\make-fake-bin.ps1 (TLS SNI-патчер +
QUIC-варианты), лежат в bin\tls_clienthello\ и bin\quic_initial\.
