# ZapretExtra v1.00 — полная документация (RU)

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
9. [Списки domains и ipsets](#9-списки-domains-и-ipsets)
10. [Бинарные файлы и фейки](#10-бинарные-файлы-и-фейки)
11. [Обновления](#11-обновления)
12. [Служба Windows](#12-служба-windows)
13. [Диагностика и FAQ](#13-диагностика-и-faq)
14. [Атрибуция и лицензия](#14-атрибуция-и-лицензия)
15. [История версий](#15-история-версий)

---

## 1. Что это

**ZapretExtra v1.00** — усиленная Windows-сборка для обхода DPI-блокировок
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
- разложенными по сервисам списками доменов и подсетей.

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
   в параметрах Windows 11. Без этого часть подмен не лечится (см. п.13).
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
├── update-aws.ps1            # обновление AWS-списка с GitHub
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
│   │                         # instagram, general (+user/exclude)
│   └── ipsets/               # all, cloudflare, amazon, exclude (+user),
│                             # resolved/ — снапшоты резолвинга
└── utils/
    ├── test zapret.ps1       # тесты (режимы/профили/лимиты)
    ├── targets.txt           # 51 мишень тестов
    ├── build-custom-preset.ps1  # конструктор
    ├── build-service-ipsets.ps1 # резолвинг доменов в ipsets/resolved/
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
(`ipsets\amazon.txt`, fake+autottl).

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

Главное меню (русское, 9 пунктов + выход):

1. **Запустить пресет** — временно: выбор из всех 59+ (с группировкой
   по авторам) → запуск → ожидание клавиши → остановка `winws.exe`.
   Предупредит, если служба уже запущена.
2. **Установить как службу** — разбор аргументов winws из пресета,
   `sc create start=auto` (автозапуск для всех пользователей), старт,
   запись `Папка\файл` в реестр. Учитывает Game Filter.
3. **Удалить службу** — `zapret` + `winws` + очистка WinDivert.
4. **Статус** — служба, процесс, WinDivert, текущий пресет.
5. **Обновления** — версия Flowseal; докачка новых `.bat` авторов с GitHub
   (новые файлы сами приводятся к корневому виду); обновление AWS-списка.
6. **Тесты** — подменю: Standard / DPI / Combined (см. п.7).
7. **Конструктор** — `BUILD-CUSTOM-PRESET.bat` (см. п.8).
8. **Настройки** — Game Filter вкл/выкл, IPSet `loaded/none/any`,
   проверка обновлений при запуске, ручное обновление AWS.
9. **Расширенное меню** — открывает `service.bat` (диагностика, замена
   фейков, hosts и т.д.).

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
Amazon (11), Instagram (5), X/Twitter (10), YouTube (4). Всего 51 мишень
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
  каждый рабочий домен (стратегия его победителя) + фильтры по
  `*-alive.txt` (только рабочие IP как `/32`; если рабочих нет —
  FULL-FALLBACK на полный список, иначе пустой ipset = режим «any»);
- `custom (AUTO …).bat` — полный гибрид.
- Дальше: ретест собранного (подхватывается автоматически) → установка.

---

## 9. Списки domains и ipsets

`lists\domains\`: `discord` (25), `google` (24, вкл. старый list-google),
`cloudflare` (33), `amazon` (8), `instagram` (7, новый), `general` (33,
остальное) + `general-user` (ваши домены), `exclude/exclude-user`.
Пресеты покрывают их объединением (проверено; старые плоские файлы удалены).

`lists\ipsets\`: `all` (+backup, режимы loaded/none/any), `cloudflare`
(9154 авторских диапазона), `amazon` (2810, обновляется), `exclude(+user)`,
`resolved\<сервис>` — снапшоты резолвинга доменов
(`utils\build-service-ipsets.ps1`, discord 80 … instagram 8; формат
`/32`+`/128`; нерезолвящиеся имена печатаются — обычно мёртвые).
Resolved-файлы пока никуда не подключены (заготовка под точечные фильтры).

---

## 10. Бинарные файлы и фейки

`bin\`: `winws.exe`, `WinDivert.*`, `cygwin1.dll`, `ACTIVE_*.bin`,
`stun*.bin` + подпапки `tls_clienthello/` (12 шт.) и `quic_initial/`
(13 шт.). `utils\make-fake-bin.ps1` генерирует фейки под новые домены:
TLS — настоящий патч SNI с пересчётом длин (self-test побайтово);
QUIC Initial шифрован (SNI не виден) — делаются валидные 1200-байтные
варианты со случайным DCID. Замена активных фейков — через меню.

---

## 11. Обновления

- Менеджер пункт 5 → `utils\sync-presets.ps1`: версия Flowseal;
  новые `.bat` Flowseal докачиваются из корня репозитория;
  для StressOzz (стратегии в `.md`) запускается
  `utils\convert-stressozz.ps1` (пересборка v/youtube-пресетов).
  Скачанное приводится к корневому виду (`convert-preset.ps1`).
  Ссылки на репозитории — в `Presets\<автор>\repo.url`.
- AWS-лист: `update-aws.ps1` (при каждом запуске пресетов Flowseal).
- IPSet `all.txt`: пункт меню service.bat.

---

## 12. Служба Windows

Имя службы — `zapret` (не менять: от него зависят тесты и WinDivert).
Установка — менеджер пункт 2 / service.bat: разбор аргументов,
`timestamps=enabled`, `sc create start=auto`, старт, имя пресета
(`Папка\файл`) — в `HKLM\...\Services\zapret` (поле `zapret-discord-youtube`).
Удаление чистит службу, `winws.exe`, `WinDivert/WinDivert14`.

---

## 13. Диагностика и FAQ

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

## 14. Атрибуция и лицензия

См. [ATTRIBUTION.md](../ATTRIBUTION.md) и [LICENSE.txt](../LICENSE.txt)
(MIT; бинарники bol-van/zapret, WinDivert — LGPLv3/GPLv2 на выбор).
Основа — Flowseal/zapret-discord-youtube; AWS/Cloudflare-материалы —
fallonightcorp/zapret-aws-cloudflare; тексты v1–v10/Yv — StressOzz;
DPI-набор тестов — hyperion-cs/dpi-checkers (Apache-2.0, подтягивается
в рантайме, не распространяется). Всё используется со ссылками и
лицензиями; правообладателям — открывайте issue.

---

## 15. История версий

- **1.00** — первый публичный выпуск ZapretExtra: 59 пресетов (Flowseal 22
  + StressOzz 37), менеджер, тесты (3 режима, 6 профилей, лимиты),
  конструктор (гибрид + 3 семейных), списки по сервисам, фейки по доменам,
  обновления с GitHub, документация RU/EN.
