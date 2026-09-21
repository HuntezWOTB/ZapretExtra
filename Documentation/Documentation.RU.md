# ZapretExtra v1.01 — полная документация (RU)

> [English version](Documentation.EN.md) · [На главную](../README.md)

## Содержание

1. [Что это](#1-что-это)
2. [Быстрый старт](#2-быстрый-старт)
3. [Структура папок](#3-структура-папок)
4. [Пресеты](#4-пресеты)
5. [Менеджер ZAPRET.bat](#5-менеджер-zapretbat)
6. [service.bat (расширенное меню)](#6-servicebat-расширенное-меню)
7. [Тесты стратегий](#7-тесты-стратегий)
8. [Конструктор пресетов](#8-конструктор-пресетов)
9. [LIVE-подбор пресета](#9-live-подбор-пресета)
10. [Списки domains и ipsets](#10-списки-domains-и-ipsets)
11. [Бинарные файлы и фейки](#11-бинарные-файлы-и-фейки)
12. [Обновления](#12-обновления)
13. [Служба Windows](#13-служба-windows)
14. [Диагностика и FAQ](#14-диагностика-и-faq)
15. [Атрибуция и лицензия](#15-атрибуция-и-лицензия)
16. [История версий](#16-история-версий)

---

## 1. Что это

**ZapretExtra v1.01** — усиленная Windows-сборка для обхода DPI-блокировок
(программный уровень, через WinDivert + winws). Собрана на основе
[Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
(base 1.10.3) и дополнена:

- интеграцией Cloudflare + Amazon (материалы
  [fallonightcorp/zapret-aws-cloudflare](https://github.com/fallonightcorp/zapret-aws-cloudflare));
- 37 стратегиями StressOzz из сборки
  [Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)
  (v1–v10 и YouTube v01–v27, тексты стратегий, адаптированы под winws);
- русскоязычным менеджером `ZAPRET.bat`;
- профильными тестами и конструктором персональных пресетов;
- разложенными по сервисам списками доменов и подсетей;
- LIVE-подбором пресета под приложение/сайт (пункт 11: захват трафика →
  перебор → точечный пресет, см. п.9);
- заблокированными категориями (Telegram/Twitter/Facebook — свои файлы,
  WhatsApp/OpenAI/Netflix/TikTok — в `general.txt`, без дублей) и
  автообновлением IP-диапазонов крупных сервисов (Telegram/Facebook/
  Twitter через RIPEstat, Amazon/CloudFront — официальные списки).

Всего из коробки — **59 пресетов**, плюс сколько угодно собранных вами.

---

## 2. Быстрый старт

1. **Скачивание.** Зелёная кнопка **Code** вверху страницы репозитория →
   **Download ZIP**. Распакуйте архив.
2. **Путь.** Положите папку туда, где нет кириллицы и пробелов, например
   `C:\ZapretExtra`. В свойствах ZIP поставьте «Разблокировать» (если есть).
3. **Антивирус.** Добавьте папку в исключения: `WinDivert.sys`/`WinDivert.dll`
   детектятся как RiskTool/HackTool — это штатно для перехвата трафика,
   вирусом не является.
4. **DNS.** Включите защищённый DNS (DoH): в браузере (Chrome/Firefox) или
   в параметрах Windows 11. Без этого часть подмен не лечится (см. п.14).
5. **Запуск.** Правой кнопкой по `ZAPRET.bat` ничего делать не надо —
   просто запустите, права администратора запросятся сами:
   - пункт **6** → тесты → узнайте, какая стратегия работает у вас;
   - пункт **2** → поставьте её как службу (автозапуск для всех).
6. **Своя стратегия.** Пункт **7** соберёт гибрид/семейные пресеты из ваших
   результатов тестов → ретест → установка службой.

---

## 3. Структура папок

```
ZapretExtra/
├── ZAPRET.bat                # главный менеджер (русское меню, OEM 866)
├── service.bat               # расширенное меню оригинала
├── BUILD-CUSTOM-PRESET.bat   # лаунчер конструктора
├── Apps/                     # bat-лаунчеры приложений (пункт 10)
├── update-aws.ps1            # обновление Amazon (офиц.) + CloudFront
├── utils/update-blocklists.ps1  # домены блоклистов (merge/check)
├── utils/update-service-ips.ps1 # IP-диапазоны Telegram/Facebook/Twitter
├── LICENSE.txt / ATTRIBUTION.md / README*.txt / .gitattributes
├── Presets/
│   ├── Flowseal/             # 22 стратегии general*.bat
│   ├── StressOzz/            # v1-v10 + youtube-v01-v27 (+README)
│   └── Custom/               # ваши собранные пресеты
├── bin/
│   ├── winws.exe, WinDivert.*, cygwin1.dll
│   ├── ACTIVE_*.bin, stun*.bin
│   ├── tls_clienthello/      # ClientHello-фейки по доменам
│   └── quic_initial/         # QUIC Initial-фейки
├── lists/
│   ├── domains/              # discord, google, cloudflare, amazon,
│   │                         # instagram, telegram, twitter, facebook,
│   │                         # general (+user/exclude)
│   └── ipsets/               # all, cloudflare, amazon, cloudfront,
│                             # telegram, facebook, twitter, exclude (+user),
│                             # discord/google/instagram/general.txt — IP-снапшоты
└── utils/
    ├── test zapret.ps1       # тесты (режимы/профили/лимиты)
    ├── targets.txt           # 59 мишеней тестов
    ├── watch-app.ps1         # LIVE шаг 1: захват трафика
    ├── live-pick.ps1         # LIVE шаг 2: перебор + point-пресет
    ├── live results/         # ранжированные попытки LIVE
    ├── build-custom-preset.ps1  # конструктор
    ├── build-service-ipsets.ps1 # резолвинг доменов в ipsets/<сервис>.txt
    ├── convert-preset.ps1    # приведение .bat к корневому виду
    ├── convert-stressozz.ps1 # пересборка пресетов StressOzz с GitHub
    ├── sync-presets.ps1      # проверка обновлений пресетов
    ├── make-fake-bin.ps1     # генератор фейков под новые домены
    └── test results/         # результаты ваших прогонов (.txt + .json)
```

Пресеты обращаются к корню через переменную `ROOT` (два уровня вверх),
поэтому их можно свободно раскладывать по подпапкам `Presets\`.

---

## 4. Пресеты

### 4.1. Flowseal (22 шт., `Presets\Flowseal\`)

Классика `general*.bat` (base 1.10.3): multisplit / fake+fakesplit /
hostfakesplit / FAKE TLS AUTO / SIMPLE FAKE + EXP, ALT–ALT13. Во все
встроено: автообновление AWS-листа, WFP-порты `444-65535`, фильтры
Cloudflare (`ipsets\cloudflare.txt`, стратегия как у `all.txt`) и Amazon
(`ipsets\amazon.txt`, fake+autottl). В general-линии (TCP 80,443 и UDP 443)
подключены также `telegram.txt`, `twitter.txt`, `facebook.txt`.

### 4.2. StressOzz (37 шт., `Presets\StressOzz\`)

- **v1–v10** — стратегии TCP/443 из `Strategies.md` + Discord-блоки
  (UDP voice + `discord.media`) + game-блок автора (через Game Filter).
- **youtube-v01–v27** — стратегии из `Strategies_For_Youtube.md`
  по `domains\google.txt`.
- Пути фейков пересчитаны на локальные `bin\` (включая сгенерированные
  `tls_clienthello_vk_com.bin`, `gosuslugi_ru.bin`; `4pda.bin` автора =
  наш `tls_clienthello_4pda_to.bin`). Стратегии оставлены дословно,
  известные шероховатости оригинала: `fakeddisorder` (v5, Yv05, Yv17,
  Yv23), `--autottl 2:2-12` (Yv06), `--dup*` (Yv17) — winws их может
  не принять; тесты это честно покажут статусом запуска.

### 4.3. Custom (`Presets\Custom\`)

Сюда конструктор складывает `preset-aws-only / cloudflare-only /
aws-cloudflare / custom (AUTO <дата>).bat`. Менеджер, тесты и установка
службой видят их автоматически.

---

## 5. Менеджер ZAPRET.bat

Главное меню (русское, 11 пунктов + выход):

1. **Запустить пресет** — временно: выбор из всех 59+ (с группировкой
   по авторам) → запуск → ожидание клавиши → остановка `winws.exe`.
   Предупредит, если служба уже запущена.
2. **Установить как службу** — разбор аргументов winws из пресета,
   `sc create start=auto` (автозапуск для всех пользователей), старт,
   запись `Папка\файл` в реестр. Учитывает Game Filter.
3. **Удалить службу** — `zapret` + `winws` + очистка WinDivert.
4. **Статус** — служба, процесс, WinDivert, текущий пресет.
5. **Обновления** — версия Flowseal; докачка новых `.bat` авторов с GitHub
   (новые файлы сами приводятся к корневому виду + получают новые
   hostlist); обновление AWS + CloudFront; обновление заблокированных
   доменов (`update-blocklists.ps1`: merge/check по 12 источникам);
   обновление IP-диапазонов Telegram/Facebook/Twitter
   (`update-service-ips.ps1`, RIPEstat).
6. **Тесты** — подменю: Standard / DPI / Combined (см. п.7).
7. **Конструктор** — `BUILD-CUSTOM-PRESET.bat` (см. п.8).
8. **Настройки** — Game Filter вкл/выкл, IPSet `loaded/none/any`,
   проверка обновлений при запуске, ручное обновление IP-списков.
9. **Расширенное меню** — открывает `service.bat` (диагностика, замена
   фейков, hosts и т.д.).
10. **Приложение через обход** — запуск `.exe` через выбранный пресет
    (временно, остановка по клавише; последний путь помнится) и генератор
    `Apps\App-<имя>.bat` (двойной клик). Проверки: существование exe,
    ожидание `winws` до 20 сек с варнингом, старт приложения.
    Отдельно есть переносимый `Generate_Start_App_Via_Preset.bat`
    (релиз не трогает): выбор exe и пресета окнами проводника, выход —
    `<Exe>_ZapretExtra_<Preset>.bat` в `Generated_BatPreset_for_App\`.
    Честно: фильтра по процессу в winws нет, обход на время сессии
    действует системно.
11. **LIVE-подбор** — динамический подбор пресета под приложение/сайт
    (см. п.9): захват трафика → перебор → точечный пресет.

> Техническое: файл в кодировке OEM 866 (иначе cmd.exe портит кириллицу).
> Править — только через цикл UTF-8 → правка → 866.

---

## 6. service.bat (расширенное меню)

Оригинальное меню Flowseal, обновлено под новую структуру (видит пресеты
в подпапках, пути списков новые). Сохранено полностью: Game Filter,
IPSet-переключатель, Auto-Update Check, Replace active fakes (ищет
рекурсивно, включая подпапки `bin\`), Update IPSet/Hosts, Check Updates,
Diagnostics (с очисткой кэша Discord), Run Tests.

---

## 7. Тесты стратегий

Запуск: менеджер пункт 6 (или `service.bat` → Run Tests). Требуются права
администратора, служба `zapret` на время тестов должна быть удалена.

**Режим:** `[1]` Standard — HTTP-пробы (HTTP, TLS 1.1/1.2/1.3) + пинг;
`[2]` DPI checkers — замирание TCP 16–20 (набор hyperion-cs/dpi-checkers);
`[3]` Combined — оба за один прогон (DPI-строки помечены `[dpi]`,
выбираются Best config и Best DPI config).

**Профили:** All, Discord (signalling+медиа; войс/экран идут через
одинаковые во всех пресетах UDP L7-фильтры), Cloudflare (11 серверов),
Amazon (11), Instagram (5), X/Twitter (10), YouTube (4), Telegram (4),
Facebook (4). Всего 59 мишеней
(`utils\targets.txt`, ключи — одним словом).

**Лимиты** (вопрос перед прогоном, `0` — без лимита; либо env
`TEST_RESP_LIMIT` / `TEST_PING_LIMIT`): ответ дольше N сек (по умолч. 2) →
токен `TIMEENDED` (как ошибка, считается отдельно); пинг дольше M мс
(по умолч. 100) → `SLOW` (провал пинга везде).

**Факторы выбора:** больше OK → меньше ERROR(+TIMEENDED) → живой пинг →
меньше loss% (пинг — 4 эха, формат `12 ms, loss 0%`).

**Выход:** `utils\test results\test_results_<дата>.txt + .json`
(type, profile, лимиты, best, bestDpi) — вход для конструктора.

---

## 8. Конструктор пресетов

Запуск: `BUILD-CUSTOM-PRESET.bat` (ядро — `utils\build-custom-preset.ps1`,
админ не нужен). Показывает файлы результатов со сводкой
`тип | профиль | best | дата` и подсказки, какой тест прогнать.

**Логика:**
- для каждого домена — личный победитель (все 5 факторов);
- для каждого IP — рабочий/нет (пинг OK минимум в половине прогонов);
- упавшие серверы исключаются (типично «8 из 11»);
- классы winws-фильтров голосуют, шаблон — overall-best, подменяется
  только `--dpi-desync`-сегмент (структура всегда валидна);
- штраф за DPI-блокировки (`LIKELY_BLOCKED/FAIL` из dpi-записей того же
  прогона) — франкенштейн собирается с учётом DPI-проверок.

**Выход** (в `Presets\Custom\`):
- `preset-aws-only / cloudflare-only / aws-cloudflare (AUTO …).bat` —
  один общий файл на семью: точечные `--hostlist-domains=` строки под
  каждый рабочий домен (стратегия его победителя) + фильтры по полным
  спискам (`amazon.txt` / `cloudflare.txt`);
- `custom (AUTO …).bat` — полный гибрид.
- Дальше: ретест собранного (подхватывается автоматически) → установка.

---

## 9. LIVE-подбор пресета (пункт 11)

Динамический подбор под конкретное приложение или сайт (например, игра
на AWS/Cloudflare): захват реального трафика -> перебор пресетов по
захваченным адресам -> точечный пресет.

**Шаг 1 — захват** (`utils\watch-app.ps1`): по имени `.exe` (поллинг
соединений процесса; длительность 10-300 сек, по умолч. 45 — для быстрой
проверки «прогрузились ли картинки» хватает 15) или по домену/IP вручную.
На выходе `utils\live-targets.txt` (мишени) + `utils\live-capture.json`.
По каждому домену: хиты, порты, пинг, TCP-коннект, HTTP-проверка (код +
время — видно, грузится ли контент), вердикт OK/SUSPECT, тег сети
(CloudFront/AWS/Telegram/Facebook/Twitter/known:<сервис>), CNAME-цепочка
(показывает, на каком CDN реально сидит домен).

**Шаг 2 — подбор** (`utils\live-pick.ps1`): быстрый топ-12 / вручную /
все пресеты. Автозамеры (HTTP, пинг, TCP) + ваша оценка после живой пробы
игры (время на пробу настраивается, по умолч. 20 сек). Все попытки копятся
в `utils\live results\`, строится общий рейтинг; из победителя собирается
`Presets\Custom\preset-point (AUTO …).bat` — узкие фильтры только под
захваченные хосты (+первые блоки CloudFront/Telegram по совпавшим CIDR:
IP ротируются, диапазоны — нет).
Честно: UDP-эндпоинты автопробником не меряются (TCP-коннект к UDP-порту
бессмыслен) — для них оракул только ваша оценка. Перебор briefly
останавливает текущий winws и восстанавливает его после (со службой тоже
работает, спросит подтверждение).

---
## 10. Списки domains и ipsets

`lists\domains\`: `discord` (26), `google` (187, вкл. региональные YouTube),
`cloudflare` (46), `amazon` (106), `instagram` (7), `telegram` (21),
`twitter` (24), `facebook` (18, курированная инфра), `general` (127, вкл.
WhatsApp/OpenAI/Netflix/TikTok) + `general-user` (ваши домены),
`exclude/exclude-user`. Дублей между файлами нет (аудит); пресеты покрывают
их объединением.

`lists\ipsets\`: `all` (режимы loaded/none/any; старого `.backup` больше нет —
возврат в `loaded` перекачивает список из репозитория Flowseal), `cloudflare`
(9154 авторских диапазона), `amazon` (официальные диапазоны AWS + кэш),
`cloudfront` (211 официальных CIDR), `telegram` (24, AS62041),
`facebook` (240, AS32934), `twitter` (27, AS13414 — все через RIPEstat),
`exclude(+user)`,
`discord/google/instagram/general.txt` — IP-снапшоты резолвинга,
один файл на сервис
(`utils\build-service-ipsets.ps1`; формат `/32`+`/128`;
нерезолвящиеся имена печатаются — обычно мёртвые).
Файлы служат known-IP оракулом для `utils\watch-app.ps1`
(тег `known:<сервис>`) и готовы как селективный `--ipset`
для точечных пресетов; в общие списки не мержим (протухают).

---

## 11. Бинарные файлы и фейки

`bin\`: `winws.exe`, `WinDivert.*`, `cygwin1.dll`, `ACTIVE_*.bin`,
`stun*.bin` + подпапки `tls_clienthello/` (14 шт.) и `quic_initial/`
(14 шт.). `utils\make-fake-bin.ps1` генерирует фейки под новые домены:
TLS — настоящий патч SNI с пересчётом длин (self-test побайтово);
QUIC Initial шифрован (SNI не виден) — делаются валидные 1200-байтные
варианты со случайным DCID. Замена активных фейков — через меню.

---

## 12. Обновления

- Менеджер пункт 5 → `utils\sync-presets.ps1`: версия Flowseal;
  новые `.bat` Flowseal докачиваются из корня репозитория;
  для StressOzz (стратегии в `.md`) запускается
  `utils\convert-stressozz.ps1` (пересборка v/youtube-пресетов).
  Скачанное приводится к корневому виду (`convert-preset.ps1`).
  Ссылки на репозитории — в `Presets\<автор>\repo.url`.
- AWS и CloudFront: `update-aws.ps1` (при каждом запуске пресетов Flowseal;
  Amazon — официальные AMAZON+EC2 + кэш, CloudFront — официальный лист
  с fallback на `ip-ranges.json`).
- Заблокированные домены: `utils\update-blocklists.ps1` (12 источников
  v2fly/domain-list-community: merge недостающего, check для Facebook;
  осознанно НЕ тянем google-ads, спам, steam/twitch, 700k-листы).
- IP-диапазоны сервисов: `utils\update-service-ips.ps1` (Telegram,
  Facebook, Twitter через RIPEstat announced-prefixes).
- IPSet `all.txt`: пункт меню service.bat.

---

## 13. Служба Windows

Имя службы — `zapret` (не менять: от него зависят тесты и WinDivert).
Установка — менеджер пункт 2 / service.bat: разбор аргументов,
`timestamps=enabled`, `sc create start=auto`, старт, имя пресета
(`Папка\файл`) — в `HKLM\...\Services\zapret` (поле `zapret-discord-youtube`).
Удаление чистит службу, `winws.exe`, `WinDivert/WinDivert14`.

---

## 14. Диагностика и FAQ

- **Ничего не работает** — service.bat → Diagnostics; Secure DNS;
  другие стратегии; `netsh winsock reset` + `netsh int ip reset` +
  `ipconfig /flushdns` + перезагрузка.
- **Токен SSL в тестах** — несоответствие сертификата (возможна подмена,
  см. ниже) — не ошибка стратегии как таковой.
- **Подмена CDN**: SNI-подмену на лету лечат десинки (прячут SNI);
  DNS-подмену (чужой IP вместо Cloudflare/Google) — только DoH/DoT и hosts.
  «Принять и фейк, и оригинал» нельзя: TLS-сессия одна, подменённый ответ
  её ломает. Токен `SSL` в тестах такой случай и ловит.
- **Игры/приложения ломаются** — Game Filter `disabled`, IPSet `none`.
- **Античит** — см. windivert-hide у bol-van.
- **Win7** — заменить WinDivert* из zapret-win-bundle/win7.
- **Стратегия перестала работать** — нормально со временем: ретест +
  пересборка конструктором.

---

## 15. Атрибуция и лицензия

См. [ATTRIBUTION.md](../ATTRIBUTION.md) и [LICENSE.txt](../LICENSE.txt)
(MIT; бинарники bol-van/zapret, WinDivert — LGPLv3/GPLv2 на выбор).
Основа — Flowseal/zapret-discord-youtube; AWS/Cloudflare-материалы —
fallonightcorp/zapret-aws-cloudflare; тексты v1–v10/Yv — StressOzz;
DPI-набор тестов — hyperion-cs/dpi-checkers (Apache-2.0, подтягивается
в рантайме, не распространяется); категории доменов —
v2fly/domain-list-community (MIT, агрегатор runetfreedom); IP-диапазоны
сервисов — RIPEstat. Всё используется со ссылками и лицензиями;
правообладателям — открывайте issue.

---

## 16. История версий

- **1.01** — LIVE-подбор (захват трафика + перебор + point-пресеты),
  заблокированные категории (Telegram/Twitter/Facebook — свои файлы;
  WhatsApp/OpenAI/Netflix/TikTok — в `general.txt`; топ-апы своих),
  IP-диапазоны Telegram/Facebook/Twitter (RIPEstat) + CloudFront,
  Amazon на официальном источнике, чистка дубликатов и `PS 5.1`-фиксы
  кодировок, тесты Telegram/Facebook (профили 7–8).
- **1.00** — первый публичный выпуск ZapretExtra: 59 пресетов (Flowseal 22
  + StressOzz 37), менеджер, тесты (3 режима, 6 профилей, лимиты),
  конструктор (гибрид + 3 семейных), списки по сервисам, фейки по доменам,
  обновления с GitHub, документация RU/EN.
