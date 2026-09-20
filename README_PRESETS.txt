ZapretExtra Manager + папка Presets
===============================
Главная точка входа: ZAPRET.bat (русское меню, сам запрашивает админа).

Структура пресетов (папка Presets):
  Flowseal\   — 22 стратегии general*.bat от Flowseal
                (https://github.com/Flowseal/zapret-discord-youtube),
                с интеграцией AWS/Cloudflare.
  StressOzz\  — 37 стратегий от StressOzz
                (https://github.com/StressOzz/Zapret-Manager):
                v1..v10 из Strategies.md (+Discord +game блоки автора),
                youtube-v01..v27 из Strategies_For_Youtube.md.
                Собраны конвертером utils\convert-stressozz.ps1.
  Custom\     — сюда конструктор складывает собранные пресеты
                (preset-aws-only / cloudflare-only / aws-cloudflare /
                custom). Пустая после очистки.

Меню ZAPRET.bat:
  1. Запустить пресет — временно: запуск, ожидание клавиши, остановка
     winws. Если служба запущена — предупредит.
  2. Установить как службу — выбор пресета, разбор аргументов winws,
     sc create (start=auto, для всех пользователей), sc start, запись
     имени "Папка\файл" в реестр. Учитывает Game Filter.
  3. Удалить службу — zapret + winws + WinDivert.
  4. Статус — служба, процесс, WinDivert, текущий пресет.
  5. Обновления — версия Flowseal; докачка новых .bat авторов с GitHub
     (utils\sync-presets.ps1, новые файлы сами приводятся к корневому
     виду); обновление AWS-списка.
  6. Тесты — открывает utils\test zapret.ps1 (режим/профиль/лимиты).
  7. Конструктор — BUILD-CUSTOM-PRESET.bat.
  8. Настройки — Game Filter вкл/выкл, IPSet loaded/none/any, проверка
     обновлений при запуске, ручное обновление AWS.
  9. Расширенное меню — старый service.bat (диагностика, замена
     фейков, hosts и т.д.). service.bat тоже обновлен: видит пресеты
     в подпапках.

Технически: пресеты лежат на 2 уровня ниже корня и обращаются к нему
через переменную ROOT (задает каждый пресет сам). utils\convert-preset.ps1
приводит любой .bat к такому виду — используется при переезде и при
скачивании обновлений. Тесты и конструктор ищут пресеты рекурсивно;
в отчетах конфиги подписаны "Папка\файл".
