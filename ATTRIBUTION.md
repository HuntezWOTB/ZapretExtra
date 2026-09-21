# ZapretExtra — attribution of third-party materials.
# Kept to avoid any intellectual-property questions: everything below
# is used with its original license/terms, links included.

1. Base distribution
   - Flowseal/zapret-discord-youtube (MIT)
   - https://github.com/Flowseal/zapret-discord-youtube
   - Presets general*.bat, service.bat logic, lists, utils/tests, docs.
   - Binaries in bin\ come from bol-van/zapret and basil00/WinDivert
     (see LICENSE.txt for their terms).

2. AWS/Cloudflare integration
   - fallonightcorp/zapret-aws-cloudflare
   - https://github.com/fallonightcorp/zapret-aws-cloudflare
   - ipset-cloudflare list, AWS IP list concept, update approach.

3. Strategies v1-v10 and youtube-v01-v27 (texts only, adapted to winws)
   - StressOzz/Zapret-Manager (Strategies.md, Strategies_For_Youtube.md)
   - https://github.com/StressOzz/Zapret-Manager
   - Converted to Windows .bat by utils\convert-stressozz.ps1; fake-file
     paths remapped to local bin\; behaviour otherwise unchanged.

4. DPI checker suite (used by utils\test zapret.ps1, Apache-2.0)
   - https://github.com/hyperion-cs/dpi-checkers
   - Fetched at test runtime, not redistributed.

5. Blocked-domain categories (lists\domains\: telegram/twitter/facebook
   new files, general.txt top-ups for whatsapp/openai/netflix/tiktok,
   missing-entry top-ups for discord/youtube/google/cloudflare/amazon)
   - v2fly/domain-list-community, data/* categories (MIT)
   - https://github.com/v2fly/domain-list-community
   - Aggregated upstream: runetfreedom/russia-v2ray-rules-dat
   - https://github.com/runetfreedom/russia-v2ray-rules-dat
   - Merged by utils\update-blocklists.ps1 with dedup (no entry lives in
     two files); google/ads, follower-spam, steam/twitch and the 700k
     ru-blocked-all sets are deliberately NOT imported.

6. Service IP ranges (lists\ipsets\: telegram/facebook/twitter)
   - RIPEstat announced-prefixes API (stat.ripe.net), ASN holders verified:
     Telegram/AS62041, Facebook/AS32934, Twitter/AS13414
   - https://stat.ripe.net/
   - Refreshed by utils\update-service-ips.ps1; amazon/cloudfront ranges
     come from update-aws.ps1 instead.

No binaries or texts were taken from anywhere else. If you are a
rights holder and believe something is misattributed, open an issue.
