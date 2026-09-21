# ZapretExtra v1.02 — full documentation (EN)

> [Русская версия](Documentation.RU.md) · [Home](../README.md)

## Contents

1. [What is this](#1-what-is-this)
2. [Quick start](#2-quick-start)
3. [Folder structure](#3-folder-structure)
4. [Presets](#4-presets)
5. [ZAPRET.bat manager](#5-zapretbat-manager)
6. [service.bat (extended menu)](#6-servicebat-extended-menu)
7. [Strategy tests](#7-strategy-tests)
8. [Preset builder](#8-preset-builder)
9. [LIVE preset picker](#9-live-preset-picker)
10. [Domains and ipsets lists](#10-domains-and-ipsets-lists)
11. [Binaries and fakes](#11-binaries-and-fakes)
12. [Updates](#12-updates)
13. [Windows service](#13-windows-service)
14. [Diagnostics and FAQ](#14-diagnostics-and-faq)
15. [Attribution and license](#15-attribution-and-license)
16. [Changelog](#16-changelog)

---

## 1. What is this

**ZapretExtra v1.02** is an extended Windows bundle for bypassing DPI blocks
(user-space, via WinDivert + winws). Built on top of
[Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
(base 1.10.3) and extended with:

- Cloudflare + Amazon integration (materials from
  [fallonightcorp/zapret-aws-cloudflare](https://github.com/fallonightcorp/zapret-aws-cloudflare));
- 37 StressOzz strategies from the
  [Zapret-Manager](https://github.com/StressOzz/Zapret-Manager) build
  (v1–v10 and YouTube v01–v27, strategy texts adapted for winws);
- a Russian manager `ZAPRET.bat` (menu items are in Russian; this doc covers them);
- profiled tests and a test-driven personal preset builder;
- per-service domain and subnet lists;
- a LIVE preset picker for an app/site (item 11: capture → test → point
  preset, see §9);
- blocked categories (Telegram/Twitter/Facebook get own files,
  WhatsApp/OpenAI/Netflix/TikTok live in `general.txt`, no duplicates) and
  auto-refresh of major services' IP ranges (Telegram/Facebook/Twitter via
  RIPEstat, Amazon/CloudFront from official lists).

59 presets out of the box, plus as many as you build yourself.

---

## 2. Quick start

1. **Download.** Green **Code** button at the top of the repo page →
   **Download ZIP**. Unpack it.
2. **Path.** Place the folder where there is no Cyrillic or spaces, e.g.
   `C:\ZapretExtra`. In the ZIP properties tick “Unblock” if present.
3. **Antivirus.** Add the folder to exclusions: `WinDivert.sys`/`.dll` are
   flagged as RiskTool/HackTool — standard for traffic interception, not a virus.
4. **DNS.** Enable secure DNS (DoH): in your browser or in Windows 11
   settings. Some substitutions cannot be fixed without it (see §14).
5. **Run.** Just start **`ZAPRET.bat`** (admin rights are requested
   automatically):
   - item **6** → run the tests → find your working strategy;
   - item **2** → install it as a service (autostart for all users).
6. **Your own strategy.** Item **7** builds hybrid/family presets from your
   test results → retest → install as a service.

---

## 3. Folder structure

```
ZapretExtra/
├── ZAPRET.bat                # main manager (Russian menu, OEM 866)
├── service.bat               # extended original menu
├── BUILD-CUSTOM-PRESET.bat   # builder launcher
├── CONVERT-OPENWRT.bat      # preset -> _openwrt.txt for routers
├── Apps/                     # per-app launcher bats (item 10)
├── update-aws.ps1            # refreshes Amazon (official) + CloudFront
├── utils/update-blocklists.ps1  # blocked domains (merge/check)
├── utils/update-service-ips.ps1 # Telegram/Facebook/Twitter IP ranges
├── LICENSE.txt / ATTRIBUTION.md / README*.txt / .gitattributes
├── Presets/
│   ├── Flowseal/             # 22 general* strategies
│   ├── StressOzz/            # v1-v10 + youtube-v01-v27 (+README)
│   └── Custom/               # presets you built
├── bin/
│   ├── winws.exe, WinDivert.*, cygwin1.dll
│   ├── ACTIVE_*.bin, stun*.bin
│   ├── tls_clienthello/      # per-domain ClientHello fakes
│   └── quic_initial/         # QUIC Initial fakes
├── lists/
│   ├── domains/              # discord, google, cloudflare, amazon,
│   │                         # instagram, telegram, twitter, facebook,
│   │                         # general (+user/exclude)
│   └── ipsets/               # all, cloudflare, amazon, cloudfront,
│                             # telegram, facebook, twitter, exclude (+user),
│                             # discord/google/instagram/general.txt — snapshots
└── utils/
    ├── test zapret.ps1       # tests (modes/profiles/limits)
    ├── targets.txt           # 59 test targets
    ├── watch-app.ps1         # LIVE step 1: traffic capture
    ├── live-pick.ps1         # LIVE step 2: pick + point preset
    ├── live results/         # ranked LIVE attempts
    ├── build-custom-preset.ps1  # builder
    ├── build-service-ipsets.ps1 # resolve domains into ipsets/<service>.txt
    ├── convert-preset.ps1    # normalize any .bat to root-relative form
    ├── convert-stressozz.ps1 # rebuild StressOzz presets from GitHub
    ├── sync-presets.ps1      # preset update checker
    ├── make-fake-bin.ps1     # generate fakes for new domains
    └── test results/         # your runs (.txt + .json)
```

Presets address the root via the `ROOT` variable (two levels up), so they
can live in any `Presets\` subfolder.

---

## 4. Presets

### 4.1. Flowseal (22, `Presets\Flowseal\`)

Classic `general*.bat` (base 1.10.3): multisplit / fake+fakesplit /
hostfakesplit / FAKE TLS AUTO / SIMPLE FAKE + EXP, ALT–ALT13. All include:
AWS list auto-update, `444-65535` WFP ports, Cloudflare filters
(`ipsets\cloudflare.txt`, same strategy as `all.txt`) and Amazon filters
(`ipsets\amazon.txt`, fake+autottl). The general lines (TCP 80,443 and
UDP 443) also carry `telegram.txt`, `twitter.txt`, `facebook.txt`.

### 4.2. StressOzz (37, `Presets\StressOzz\`)

- **v1–v10** — TCP/443 strategies from `Strategies.md` + Discord blocks
  (UDP voice + `discord.media`) + the author's game block (via Game Filter).
- **youtube-v01–v27** — from `Strategies_For_Youtube.md`, matched against
  `domains\google.txt`.
- Fake paths remapped to local `bin\` (including generated
  `tls_clienthello_vk_com.bin`, `gosuslugi_ru.bin`; author's `4pda.bin` =
  our `tls_clienthello_4pda_to.bin`). Strategies kept verbatim, with known
  upstream quirks: `fakeddisorder` (v5, Yv05, Yv17, Yv23),
  `--autottl 2:2-12` (Yv06), `--dup*` (Yv17) — winws may reject them;
  tests will honestly show the startup status.

### 4.3. Custom (`Presets\Custom\`)

The builder puts `preset-aws-only / cloudflare-only / aws-cloudflare /
custom (AUTO <date>).bat` here. Manager, tests and service install pick
them up automatically.

Router conversion (OpenWRT): `CONVERT-OPENWRT.bat` (or manager item 12)
opens a file picker and writes `<name>_openwrt.txt` next to the preset —
pure quoteless winws arguments (the NFQWS field rejects quotes; wrapper
stripped, paths as `/opt/zapret/...`, WinDivert `--wf-*` moved to the
header as ports) + a Russian step-by-step upload guide
(`utils\openwrt-upload-ru.txt`: WinSCP, `/opt/zapret`, NFQWS_OPT field
in Zapret-Manager_for_LuCI). Paste the content into the zapret preset
field on your router.

---

## 5. ZAPRET.bat manager

Main menu (in Russian, 12 items + exit):

1. **Run preset** — temporarily: pick from all 59+ (grouped by author) →
   run → press any key → `winws.exe` is killed. Warns if the service runs.
2. **Install as service** — parses winws args from the preset,
   `sc create start=auto` (autostart for all users), starts it, writes
   `Folder\file` to the registry. Honors Game Filter.
3. **Remove service** — `zapret` + `winws` + WinDivert cleanup.
4. **Status** — service, process, WinDivert, current preset.
5. **Updates** — Flowseal version; downloads new author `.bat`s from GitHub
   (new files are auto-normalized and get the new hostlists); refreshes
   AWS + CloudFront; refreshes blocked domains (`update-blocklists.ps1`:
   merge/check over 12 sources); refreshes Telegram/Facebook/Twitter IP
   ranges (`update-service-ips.ps1`, RIPEstat).
6. **Tests** — submenu: Standard / DPI / Combined (see §7).
7. **Builder** — `BUILD-CUSTOM-PRESET.bat` (see §8).
8. **Settings** — Game Filter on/off, IPSet `loaded/none/any`, update check
   on/off, manual IP-list refresh.
9. **Extended menu** — opens `service.bat` (diagnostics, fake swapping,
   hosts, etc.).
10. **App via bypass** — run any `.exe` through a chosen preset
    (temporary, stops on keypress; last path remembered) and generate
    `Apps\App-<name>.bat` launchers (double-click). Checks: exe exists,
    up to 20 s wait for `winws` with a warning, app start. A standalone
    portable `Generate_Start_App_Via_Preset.bat` (touches nothing in the
    release) picks exe + preset via Explorer windows and writes
    `<Exe>_ZapretExtra_<Preset>.bat` into `Generated_BatPreset_for_App\`.
    Honest note: winws has no per-process filter, the bypass is
    system-wide while the session runs.
11. **LIVE picker** — dynamic preset picking for an app/site (see §9):
    traffic capture → testing → point preset.
12. **Router converter** — file-picker preset selection →
    `<name>_openwrt.txt` (quoteless clean args + Russian upload guide
    for OpenWRT with Zapret-Manager_for_LuCI: WinSCP, `/opt/zapret`,
    NFQWS_OPT field).

> Technical note: the file is OEM 866 encoded (cmd.exe mangles Cyrillic in
> UTF-8). Edit only via the UTF-8 → edit → 866 cycle.

---

## 6. service.bat (extended menu)

The original Flowseal menu, updated for the new layout (sees presets in
subfolders, new list paths). Fully kept: Game Filter, IPSet switch,
Auto-Update Check, Replace active fakes (searches recursively, including
`bin\` subfolders), Update IPSet/Hosts, Check Updates, Diagnostics (with
Discord cache cleanup), Run Tests.

---

## 7. Strategy tests

Run: manager item 6 (or `service.bat` → Run Tests). Requires admin rights;
the `zapret` service must be removed while testing.

**Mode:** `[1]` Standard — HTTP probes (HTTP, TLS 1.1/1.2/1.3) + ping;
`[2]` DPI checkers — TCP 16–20 freeze (hyperion-cs/dpi-checkers set);
`[3]` Combined — both in one run per config (DPI rows tagged `[dpi]`,
Best config and Best DPI config are picked).

**Profiles:** All, Discord (signalling+media; voice/screen-share go through
UDP L7 filters identical in all presets), Cloudflare (11 servers), Amazon
(11), Instagram (5), X/Twitter (10), YouTube (4), Telegram (4),
Facebook (4). 59 targets total
(`utils\targets.txt`, keys are single words).

**Limits** (asked before the run, `0` = no limit; or env
`TEST_RESP_LIMIT` / `TEST_PING_LIMIT`): response slower than N sec
(default 2) → `TIMEENDED` token (an error, counted separately); ping slower
than M ms (default 100) → `SLOW` (ping failure everywhere).

**Ranking factors:** more OK → fewer ERROR(+TIMEENDED) → live ping →
lower loss% (ping = 4 echoes, `12 ms, loss 0%` format).

**Output:** `utils\test results\test_results_<date>.txt + .json`
(type, profile, limits, best, bestDpi) — the builder's input.

---

## 8. Preset builder

Run: `BUILD-CUSTOM-PRESET.bat` (`utils\build-custom-preset.ps1`, no admin
needed). Lists result files with a `type | profile | best | date` summary
and hints which test to run — no need to memorize anything.

**Logic:**
- per-domain personal winner (all 5 factors);
- per-IP working/broken (ping OK in at least half the runs);
- failed servers excluded (typically “8 of 11”);
- winws filter classes vote, the template is the overall-best config, only
  the `--dpi-desync` segment is swapped (structure always stays valid);
- DPI-checker penalty (`LIKELY_BLOCKED/FAIL` from the same run's dpi rows).

**Output** (into `Presets\Custom\`):
- `preset-aws-only / cloudflare-only / aws-cloudflare (AUTO …).bat` —
  one file per family: pinpoint `--hostlist-domains=` lines for each working
  domain (its winner's strategy) + filters over the full range lists
  (`amazon.txt` / `cloudflare.txt`);
- `custom (AUTO …).bat` — full hybrid.
- Then: retest the build (picked up automatically) → install.

---

## 9. LIVE preset picker (item 11)

Dynamic picking for a specific app or site (e.g. a game on AWS/Cloudflare):
capture real traffic -> test presets against captured endpoints ->
point preset.

**Step 1 — capture** (`utils\watch-app.ps1`): by `.exe` name (polls the
process connections; 10-300 s, default 45 — 15 s is enough for a quick
"did the images load?" check) or by domain/IP manually. Outputs
`utils\live-targets.txt` (targets) + `utils\live-capture.json`.
Per-domain detail: hits, ports, ping, TCP connect, HTTP check (code +
time — shows whether content actually loads), OK/SUSPECT verdict, net tag
(CloudFront/AWS/Telegram/Facebook/Twitter/known:<service>), CNAME chain
(shows which CDN a domain really sits on).

**Step 2 — pick** (`utils\live-pick.ps1`): quick top-12 / manual / all
presets. Auto metrics (HTTP, ping, TCP) + your score after trying the
game live (soak time configurable, default 20 s). All attempts accumulate
in `utils\live results\` with a ranking; the winner builds
`Presets\Custom\preset-point (AUTO …).bat` — narrow filters only for
captured hosts (+leading CloudFront/Telegram blocks over matched CIDRs:
IPs rotate, ranges don't).
Honest note: UDP endpoints have no auto-probe (TCP-connect to a UDP port
is meaningless) — your score is the only oracle for them. Picking briefly
stops the running winws and restores it afterwards (works with the service
too, asks for confirmation).

---
## 10. Domains and ipsets lists

`lists\domains\`: `discord` (26), `google` (187, incl. regional YouTubes),
`cloudflare` (46), `amazon` (106), `instagram` (7), `telegram` (21),
`twitter` (24), `facebook` (18, curated infra), `general` (127, incl.
WhatsApp/OpenAI/Netflix/TikTok) + `general-user` (your domains),
`exclude/exclude-user`. No duplicates across files (audited); presets cover
them as a union.

`lists\ipsets\`: `all` (loaded/none/any modes; the old `.backup` is gone —
switching back to `loaded` re-downloads the list from the Flowseal repo),
`cloudflare` (9154 author ranges), `amazon` (official AWS ranges + cache),
`cloudfront` (211 official CIDRs), `telegram` (24, AS62041),
`facebook` (240, AS32934), `twitter` (27, AS13414 — all via RIPEstat),
`exclude(+user)`,
`discord/google/instagram/general.txt` — per-service IP snapshots
(`utils\build-service-ipsets.ps1`; `/32`+`/128`;
unresolvable names are printed — usually dead ones). The files feed
the known-IP oracle of `utils\watch-app.ps1` (`known:<service>` tag)
and work as selective `--ipset` for pinpoint presets;
they are not merged into range lists (they go stale).

---

## 11. Binaries and fakes

`bin\`: `winws.exe`, `WinDivert.*`, `cygwin1.dll`, `ACTIVE_*.bin`,
`stun*.bin` + `tls_clienthello/` (14) and `quic_initial/` (14) subfolders.
`utils\make-fake-bin.ps1` generates fakes for new domains: TLS = real SNI
patch with length fixes (byte-identical self-test); QUIC Initial is
encrypted (SNI invisible) — valid 1200-byte variants with random DCID.
Swap active fakes via the menu.

---

## 12. Updates

- Manager item 5 → `utils\sync-presets.ps1`: Flowseal version; new author
  `.bat`s from GitHub roots; for StressOzz (strategies live in `.md`)
  `utils\convert-stressozz.ps1` rebuilds v/youtube presets. Downloads are
  normalized via `convert-preset.ps1`. Repo links live in
  `Presets\<author>\repo.url`.
- AWS and CloudFront: `update-aws.ps1` (runs on every Flowseal preset start;
  Amazon = official AMAZON+EC2 + cache, CloudFront = official list with
  `ip-ranges.json` fallback).
- Blocked domains: `utils\update-blocklists.ps1` (12 v2fly/domain-list-community
  sources: merge what's missing, check-only for Facebook; google/ads,
  spam, steam/twitch and 700k lists deliberately skipped).
- Service IP ranges: `utils\update-service-ips.ps1` (Telegram, Facebook,
  Twitter via RIPEstat announced-prefixes).
- `all.txt` IPSet: service.bat menu item.

---

## 13. Windows service

Service name is `zapret` (do not change: tests and WinDivert depend on it).
Install — manager item 2 / service.bat: arg parsing, `timestamps=enabled`,
`sc create start=auto`, start, preset name (`Folder\file`) into
`HKLM\...\Services\zapret` (`zapret-discord-youtube` value). Removal cleans
the service, `winws.exe`, `WinDivert/WinDivert14`.

---

## 14. Diagnostics and FAQ

- **Nothing works** — service.bat → Diagnostics; secure DNS; other
  strategies; `netsh winsock reset` + `netsh int ip reset` +
  `ipconfig /flushdns` + reboot.
- **SSL token in tests** — certificate mismatch (possible substitution, see
  below) — not a strategy bug per se.
- **CDN substitution**: SNI-level substitution is treated with desyncs
  (they hide SNI); DNS substitution (a stranger IP instead of Cloudflare /
  Google) is fixed only by DoH/DoT and hosts. “Accepting both fake and
  original” is impossible: a TLS session is single-ended, a substituted
  answer breaks it. The `SSL` test token catches exactly this case.
- **Games/apps break** — Game Filter `disabled`, IPSet `none`.
- **Anticheat** — see windivert-hide at bol-van.
- **Win7** — replace WinDivert* from zapret-win-bundle/win7.
- **A strategy stopped working** — normal over time: retest + rebuild.

---

## 15. Attribution and license

See [ATTRIBUTION.md](../ATTRIBUTION.md) and [LICENSE.txt](../LICENSE.txt)
(MIT; bol-van/zapret binaries, WinDivert — LGPLv3/GPLv2 at your choice).
Base — Flowseal/zapret-discord-youtube; AWS/Cloudflare materials —
fallonightcorp/zapret-aws-cloudflare; v1–v10/Yv texts — StressOzz;
DPI test set — hyperion-cs/dpi-checkers (Apache-2.0, fetched at runtime,
not redistributed); domain categories — v2fly/domain-list-community
(MIT, aggregated by runetfreedom); service IP ranges — RIPEstat.
Everything is used with links and licenses;
rights holders — please open an issue.

---

## 16. Changelog

- **1.02** — router converter (item 12, file picker, quoteless
  `_openwrt.txt` + Russian WinSCP/NFQWS_OPT upload guide),
  OpenWRT chain localization.
- **1.01** — LIVE picker (traffic capture + testing + point presets),
  blocked categories (Telegram/Twitter/Facebook get own files;
  WhatsApp/OpenAI/Netflix/TikTok go to `general.txt`; owned top-ups),
  Telegram/Facebook/Twitter IP ranges (RIPEstat) + CloudFront,
  Amazon from the official source, duplicate cleanup and `PS 5.1`
  encoding fixes, Telegram/Facebook tests (profiles 7–8).
- **1.00** — first public ZapretExtra release: 59 presets (Flowseal 22 +
  StressOzz 37), manager, tests (3 modes, 6 profiles, limits), builder
  (hybrid + 3 families), per-service lists, per-domain fakes, GitHub
  updates, RU/EN documentation.
