# ZapretExtra v1.00 — full documentation (EN)

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
9. [Domains and ipsets lists](#9-domains-and-ipsets-lists)
10. [Binaries and fakes](#10-binaries-and-fakes)
11. [Updates](#11-updates)
12. [Windows service](#12-windows-service)
13. [Diagnostics and FAQ](#13-diagnostics-and-faq)
14. [Attribution and license](#14-attribution-and-license)
15. [Changelog](#15-changelog)

---

## 1. What is this

**ZapretExtra v1.00** is an extended Windows bundle for bypassing DPI blocks
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
- per-service domain and subnet lists.

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
   settings. Some substitutions cannot be fixed without it (see §13).
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
├── update-aws.ps1            # refreshes the AWS list from GitHub
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
│   │                         # instagram, general (+user/exclude)
│   └── ipsets/               # all, cloudflare, amazon, exclude (+user),
│                             # resolved/ — resolution snapshots
└── utils/
    ├── test zapret.ps1       # tests (modes/profiles/limits)
    ├── targets.txt           # 51 test targets
    ├── build-custom-preset.ps1  # builder
    ├── build-service-ipsets.ps1 # resolve domains into ipsets/resolved/
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
(`ipsets\amazon.txt`, fake+autottl).

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

---

## 5. ZAPRET.bat manager

Main menu (in Russian, 9 items + exit):

1. **Run preset** — temporarily: pick from all 59+ (grouped by author) →
   run → press any key → `winws.exe` is killed. Warns if the service runs.
2. **Install as service** — parses winws args from the preset,
   `sc create start=auto` (autostart for all users), starts it, writes
   `Folder\file` to the registry. Honors Game Filter.
3. **Remove service** — `zapret` + `winws` + WinDivert cleanup.
4. **Status** — service, process, WinDivert, current preset.
5. **Updates** — Flowseal version; downloads new author `.bat`s from GitHub
   (new files are auto-normalized); refreshes the AWS list.
6. **Tests** — submenu: Standard / DPI / Combined (see §7).
7. **Builder** — `BUILD-CUSTOM-PRESET.bat` (see §8).
8. **Settings** — Game Filter on/off, IPSet `loaded/none/any`, update check
   on/off, manual AWS refresh.
9. **Extended menu** — opens `service.bat` (diagnostics, fake swapping,
   hosts, etc.).

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
(11), Instagram (5), X/Twitter (10), YouTube (4). 51 targets total
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
  domain (its winner's strategy) + filters over `*-alive.txt` (working IPs
  as `/32`; FULL-FALLBACK to the full list if none — an empty ipset means
  “any” mode, so fallback is mandatory);
- `custom (AUTO …).bat` — full hybrid.
- Then: retest the build (picked up automatically) → install.

---

## 9. Domains and ipsets lists

`lists\domains\`: `discord` (25), `google` (24, incl. old list-google),
`cloudflare` (33), `amazon` (8), `instagram` (7, new), `general` (33, the
rest) + `general-user` (your domains), `exclude/exclude-user`. Presets cover
them as a union (verified; old flat files removed).

`lists\ipsets\`: `all` (+backup, loaded/none/any modes), `cloudflare`
(9154 author ranges), `amazon` (2810, updated), `exclude(+user)`,
`resolved\<service>` — domain-resolution snapshots
(`utils\build-service-ipsets.ps1`, discord 80 … instagram 8; `/32`+`/128`;
unresolvable names are printed — usually dead ones). Resolved files are not
wired anywhere yet (a stub for future pinpoint filters).

---

## 10. Binaries and fakes

`bin\`: `winws.exe`, `WinDivert.*`, `cygwin1.dll`, `ACTIVE_*.bin`,
`stun*.bin` + `tls_clienthello/` (12) and `quic_initial/` (13) subfolders.
`utils\make-fake-bin.ps1` generates fakes for new domains: TLS = real SNI
patch with length fixes (byte-identical self-test); QUIC Initial is
encrypted (SNI invisible) — valid 1200-byte variants with random DCID.
Swap active fakes via the menu.

---

## 11. Updates

- Manager item 5 → `utils\sync-presets.ps1`: Flowseal version; new author
  `.bat`s from GitHub roots; for StressOzz (strategies live in `.md`)
  `utils\convert-stressozz.ps1` rebuilds v/youtube presets. Downloads are
  normalized via `convert-preset.ps1`. Repo links live in
  `Presets\<author>\repo.url`.
- AWS list: `update-aws.ps1` (runs on every Flowseal preset start).
- `all.txt` IPSet: service.bat menu item.

---

## 12. Windows service

Service name is `zapret` (do not change: tests and WinDivert depend on it).
Install — manager item 2 / service.bat: arg parsing, `timestamps=enabled`,
`sc create start=auto`, start, preset name (`Folder\file`) into
`HKLM\...\Services\zapret` (`zapret-discord-youtube` value). Removal cleans
the service, `winws.exe`, `WinDivert/WinDivert14`.

---

## 13. Diagnostics and FAQ

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

## 14. Attribution and license

See [ATTRIBUTION.md](../ATTRIBUTION.md) and [LICENSE.txt](../LICENSE.txt)
(MIT; bol-van/zapret binaries, WinDivert — LGPLv3/GPLv2 at your choice).
Base — Flowseal/zapret-discord-youtube; AWS/Cloudflare materials —
fallonightcorp/zapret-aws-cloudflare; v1–v10/Yv texts — StressOzz;
DPI test set — hyperion-cs/dpi-checkers (Apache-2.0, fetched at runtime,
not redistributed). Everything is used with links and licenses;
rights holders — please open an issue.

---

## 15. Changelog

- **1.00** — first public ZapretExtra release: 59 presets (Flowseal 22 +
  StressOzz 37), manager, tests (3 modes, 6 profiles, limits), builder
  (hybrid + 3 families), per-service lists, per-domain fakes, GitHub
  updates, RU/EN documentation.
