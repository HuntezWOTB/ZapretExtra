# ZapretExtra v1.01

![version](https://img.shields.io/badge/version-1.01-blue)
![platform](https://img.shields.io/badge/platform-Windows-0078D6)
![license](https://img.shields.io/badge/license-MIT-green)

**ZapretExtra** — усиленная Windows-сборка обхода DPI-блокировок на базе
[Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube):
59 пресетов от двух авторов, русскоязычный менеджер, профильные тесты
(Discord / YouTube / Instagram / X / Telegram / Facebook / Cloudflare /
Amazon), LIVE-подбор пресета под приложение/сайт и конструктор,
который собирает персональный пресет из результатов ваших тестов.

> **English summary:** ZapretExtra is an extended Windows DPI-bypass bundle
> (59 presets, RU manager, profiled tests, test-driven preset builder).
> Full docs: [Documentation.EN.md](Documentation/Documentation.EN.md) ·
> Полная документация: [Documentation.RU.md](Documentation/Documentation.RU.md)

## Возможности

- **59 пресетов**: 22 Flowseal (с интеграцией Cloudflare + Amazon) + 37 StressOzz (v1–v10, YouTube v01–v27) + ваши собранные
- **LIVE-подбор (пункт 11)**: захват трафика приложения/сайта → перебор пресетов → точечный пресет с рейтингом
- **ZAPRET.bat** — русское меню: запуск, служба-автозапуск, обновления с GitHub, тесты, конструктор, настройки, запуск приложений через обход
- **Тесты в 3 режимах** (Standard / DPI / Combined) и 8 профилях, с лимитами времени и пинга
- **Конструктор пресетов** — гибрид и семейные пресеты (AWS / Cloudflare / combined) только из рабочих серверов
- **Списки по сервисам** — `lists/domains/` (вкл. Telegram/Twitter/Facebook; WhatsApp/OpenAI/Netflix/TikTok в general) и `lists/ipsets/` (вкл. официальные CloudFront + Telegram/Facebook/Twitter через RIPEstat) без дублей, с автообновлением

## Быстрый старт (5 минут)

1. Нажмите зелёную кнопку **Code** вверху страницы → **Download ZIP**.
2. В свойствах архива поставьте **«Разблокировать»** (если есть), распакуйте в путь **без кириллицы**, например `C:\ZapretExtra`.
3. Добавьте папку в исключения антивируса (WinDivert часто детектится как RiskTool — это нормально).
4. Запустите **`ZAPRET.bat`** (права администратора запросятся сами):
   - пункт **6** — прогоните тесты, узнайте рабочую стратегию;
   - пункт **2** — поставьте её как службу (автозапуск для всех пользователей).
   - пункт **11** — не работает конкретная игра/сайт: захват трафика и подбор пресета на ходу.
5. Пункт **5** — обновление всего: пресеты, AWS/CloudFront, заблокированные домены, IP-диапазоны сервисов.
5. Включите защищённый DNS (DoH) в браузере или Windows 11.

Подробно — в [полной документации](Documentation/Documentation.RU.md).

## Структура

```
ZapretExtra/
├── ZAPRET.bat            # главный менеджер (русское меню)
├── service.bat           # расширенное меню (диагностика, фейки, hosts)
├── BUILD-CUSTOM-PRESET.bat
├── update-aws.ps1        # Amazon (офиц.) + CloudFront
├── Apps/                 # ваши bat-лаунчеры приложений через обход
├── Presets/
│   ├── Flowseal/         # 22 стратегии general*
│   ├── StressOzz/        # v1-v10 + youtube-v01-v27
│   └── Custom/           # собранные вами пресеты
├── bin/                  # winws.exe, WinDivert, фейки (tls_clienthello/, quic_initial/)
├── lists/
│   ├── domains/          # домены по сервисам (discord/google/cf/amazon/instagram/telegram/twitter/facebook/general)
│   └── ipsets/           # подсети (amazon/cloudflare/cloudfront/telegram/facebook/twitter + снапшоты)
└── utils/                # тесты, LIVE-подбор, конструктор, апдейтеры, мишени
```

## Благодарности и права

- Основа: [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) (MIT), бинарники — [bol-van/zapret](https://github.com/bol-van/zapret), [WinDivert](https://github.com/basil00/WinDivert)
- AWS/Cloudflare-материалы: [fallonightcorp/zapret-aws-cloudflare](https://github.com/fallonightcorp/zapret-aws-cloudflare)
- Стратегии v1–v10, Yv01–Yv27: [StressOzz/Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)
- DPI-чекеры тестов: [hyperion-cs/dpi-checkers](https://github.com/hyperion-cs/dpi-checkers) (Apache-2.0)

Полный список — [ATTRIBUTION.md](ATTRIBUTION.md), лицензия — [LICENSE.txt](LICENSE.txt).
Используя чужие материалы только со ссылками и лицензиями — вопросов по интеллектуальной собственности быть не должно.

## ⚠️ Важно

- Стратегии со временем могут переставать работать — перепроверяйте тестами и пересобирайте пресет.
- `ipset any` и Game Filter могут ломать обычные сайты — включайте осознанно.
- Если античит игры ругается на WinDivert — см. раздел диагностики в документации.
