Списки ZapretExtra (папка lists)
====================================
Домены — lists\domains\ (по одному файлу на крупный сервис):
  discord.txt     — Discord-инфраструктура (клиент, CDN, медиа, статус)
  google.txt      — YouTube/Google (video, ggpht, ytimg, googleapis...)
  cloudflare.txt  — домены Cloudflare (portal, warp, one.one.one...)
  amazon.txt      — AWS/CloudFront (amazonaws, s3, cloudfront...)
  instagram.txt   — Instagram (web, api, cdn, graph)
  telegram.txt    — Telegram (t.me, desktop, web, cdn...)
  twitter.txt     — X/Twitter (x.com, twitter.com, twimg...)
  facebook.txt    — Facebook/Meta-инфра (курированный список: typosquat
                    из апстрима НЕ тянем; апдейтер только проверяет)
  general.txt     — всё остальное: DNS-DoH, Twitch/эмоты, Steam,
                    игры, CDN-мелочи + WhatsApp/OpenAI/Netflix/TikTok
                    из заблокированных категорий. Сюда же добавляйте свои
                    домены, если они не относятся к сервисам выше.
  (источник категорий: v2fly/domain-list-community; merge/check —
  utils\update-blocklists.ps1; дублей между файлами нет)
  general-user.txt — ВАШИ домены (создается сам при первом запуске)
  exclude.txt / exclude-user.txt — исключения (не трогать обходом)

IP-подсети — lists\ipsets\:
  all.txt — общий IP-лист (режимы loaded/none/any). Старого
    all.txt.backup больше нет (удален как бессмысленный): возврат
    в loaded перекачивает список из репозитория Flowseal.
  cloudflare.txt — подсети Cloudflare (авторский список, 9154 записи)
  amazon.txt — подсети Amazon AWS (официальные AMAZON+EC2 диапазоны
    из ip-ranges.json + сохраненный кэш, ~8000 записей;
    обновляется update-aws.ps1)
  cloudfront.txt — официальные CIDR CloudFront (211 записей;
    обновляется update-aws.ps1)
  telegram.txt, facebook.txt, twitter.txt — диапазоны сервисов
    (RIPEstat: AS62041/AS32934/AS13414, 24/240/27 записей;
    обновляется utils\update-service-ips.ps1)
  discord.txt, google.txt, instagram.txt, general.txt — снапшоты
    резолвинга domains (формат /32 и /128), по одному файлу на сервис:
    точечный пресет ссылается ровно на один (--ipset), не таща остальные.
    Создает и обновляет utils\build-service-ipsets.ps1. Служат known-IP
    оракулом для utils\watch-app.ps1 (тег known:<сервис>). Сервисы
    с диапазонными списками (amazon, cloudflare) снапшотов не имеют —
    их IP уже покрыты диапазонами. В общие списки НЕ мержим (протухают).
  exclude.txt / exclude-user.txt — исключения подсетей

Старые плоские файлы (list-general.txt, list-google.txt, ipset-all.txt
и т.д.) упразднены: пресеты ссылаются на новые пути, поведение фильтров
не изменилось (покрытие проверено объединением множеств).
