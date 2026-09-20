Списки ZapretExtra (папка lists)
====================================
Домены — lists\domains\ (по одному файлу на крупный сервис):
  discord.txt     — Discord-инфраструктура (клиент, CDN, медиа, статус)
  google.txt      — YouTube/Google (video, ggpht, ytimg, googleapis...)
  cloudflare.txt  — домены Cloudflare (portal, warp, one.one.one...)
  amazon.txt      — AWS/CloudFront (amazonaws, s3, cloudfront...)
  instagram.txt   — Instagram (web, api, cdn, graph)
  general.txt     — всё остальное: DNS-DoH, Twitch/эмоты, Steam,
                    игры, CDN-мелочи. Сюда же добавляйте свои домены,
                    если они не относятся к сервисам выше.
  general-user.txt — ВАШИ домены (создается сам при первом запуске)
  exclude.txt / exclude-user.txt — исключения (не трогать обходом)

IP-подсети — lists\ipsets\:
  all.txt (+all.txt.backup) — общий IP-лист (режимы loaded/none/any)
  cloudflare.txt — подсети Cloudflare (авторский список, 9154 записи)
  amazon.txt — подсети Amazon AWS (авторский список, 2810 записей,
    обновляется update-aws.ps1)
  exclude.txt / exclude-user.txt — исключения подсетей
  resolved\<сервис>.txt — снапшот резолвинга доменов из domains\<сервис>
    (discord 80, google 72, cloudflare 89, amazon 24, instagram 8,
    general 83 IP; формат /32 и /128). Создает и обновляет
    utils\build-service-ipsets.ps1. Нерезолвящиеся хосты печатаются
    в отчет (обычно мертвые/служебные имена) — это нормально.
    Пока никуда не подключены (заготовка под точечные фильтры).

Старые плоские файлы (list-general.txt, list-google.txt, ipset-all.txt
и т.д.) упразднены: пресеты ссылаются на новые пути, поведение фильтров
не изменилось (покрытие проверено объединением множеств).
