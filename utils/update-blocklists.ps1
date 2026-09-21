# update-blocklists.ps1 — blocked-domain lists from v2fly/domain-list-community
# (aggregated by runetfreedom/russia-v2ray-rules-dat, refreshed every 6h).
# Popular services get their own files (telegram/twitter/facebook),
# everything else circumvention-relevant goes to general.txt.
# Rules (shared by initial import and every update):
#  - merge mode: append only MISSING entries (never delete local lines);
#  - check mode: report only, never write (facebook: upstream is a typosquat farm);
#  - includes/regexps/keywords are skipped (not expressible as hostlist);
#  - no duplicates: an entry lives in the FIRST file that claims it
#    (existing files win; excludes always win and are never imported);
#  - google upstream (609 ads/trackers) and instagram upstream (follower-spam)
#    are skipped entirely; steam/twitch skipped (project-curated excludes).
# ASCII-only, PS 5.1 safe.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$domDir = Join-Path $rootDir "lists\domains"
$base = "https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/"

# curated Facebook infra (upstream facebook category is ~95% typosquat junk;
# only real infrastructure is kept; updater never auto-merges into this file)
$facebookCurated = @(
  'facebook.com','fb.com','fb.me','fb.watch','fb.gg',
  'fbcdn.com','fbsbx.com','fbsbx.net','tfbnw.net',
  'messenger.com','m.me','fbmessenger.com',
  'internet.org','freebasics.com','freebasics.net',
  'fburl.com','gameroom.com','fbcdn-a.akamaihd.net'
)

# manifest: id, upstream file, local file, mode, optional rules
$sources = @(
  @{ Id='telegram';   Up='telegram';   Local='telegram.txt'; Mode='merge' },
  @{ Id='twitter';    Up='twitter';    Local='twitter.txt';  Mode='merge' },
  @{ Id='messenger';  Up='messenger';  Local='facebook.txt'; Mode='merge'; SkipExact=@('nbabot.net') },
  @{ Id='whatsapp';   Up='whatsapp';   Local='general.txt';  Mode='merge' },
  @{ Id='openai';     Up='openai';     Local='general.txt';  Mode='merge' },
  @{ Id='netflix';    Up='netflix';    Local='general.txt';  Mode='merge' },
  @{ Id='tiktok';     Up='tiktok';     Local='general.txt';  Mode='merge' },
  @{ Id='discord';    Up='discord';    Local='discord.txt';  Mode='merge'; SkipSections='other|unused' },
  @{ Id='youtube';    Up='youtube';    Local='google.txt';   Mode='merge' },
  @{ Id='cloudflare'; Up='cloudflare'; Local='cloudflare.txt'; Mode='merge'; RequireToken='cloudflare'; Allow=@('imagedelivery.net','r2.dev') },
  @{ Id='amazon';     Up='amazon';     Local='amazon.txt';   Mode='merge'; RequireTokens=@('amazon','amzn','a2z','alexa','audible') },
  @{ Id='facebook';   Up='facebook';   Local='facebook.txt'; Mode='check' }
)

function Convert-Upstream($lines, $cfg) {
  $out = @()
  $section = ''
  $skipped = @{ Include=0; Expr=0; Section=0; Bad=0 }
  foreach ($raw in $lines) {
    $s = $raw.Trim()
    if (-not $s) { continue }
    if ($s.StartsWith('#')) { $section = $s; continue }
    if ($s.StartsWith('include:')) { $skipped.Include++; continue }
    if ($s.StartsWith('keyword:') -or $s.StartsWith('regexp:')) { $skipped.Expr++; continue }
    if ($cfg.SkipSections -and ($section -match $cfg.SkipSections)) { $skipped.Section++; continue }
    $m = [regex]::Match($s, '^(full:|domain:)?([^@\s]+?)(\s+@.*)?$')
    if (-not $m.Success) { $skipped.Bad++; continue }
    $dom = $m.Groups[2].Value.ToLower().TrimEnd('.')
    if ($dom -notmatch '^[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?$') { $skipped.Bad++; continue }
    if ($dom -notmatch '\.') { $skipped.Bad++; continue }
    if ($cfg.SkipExact -and ($cfg.SkipExact -contains $dom)) { $skipped.Section++; continue }
    $ok = $true
    if ($cfg.RequireToken) { $ok = $dom -match $cfg.RequireToken }
    if ($cfg.RequireTokens) {
      $ok = $false
      foreach ($tk in $cfg.RequireTokens) { if ($dom -match $tk) { $ok = $true; break } }
    }
    if ($cfg.Allow -and ($cfg.Allow -contains $dom)) { $ok = $true }
    if (-not $ok) { $skipped.Section++; continue }
    $out += $dom
  }
  return @{ Entries=@($out | Sort-Object -Unique); Skipped=$skipped }
}

function Get-GlobalHave {
  $have = @{}
  foreach ($f in (Get-ChildItem -LiteralPath $domDir -Filter '*.txt' -File -ErrorAction SilentlyContinue)) {
    foreach ($ln in (Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
      $t = $ln.Trim().ToLower()
      if ($t -and -not $t.StartsWith('#') -and -not $have.ContainsKey($t)) { $have[$t] = $f.Name }
    }
  }
  return $have
}

function Get-Excludes {
  $ex = @{}
  foreach ($n in @('exclude.txt','exclude-user.txt')) {
    $p = Join-Path $domDir $n
    if (-not (Test-Path -LiteralPath $p)) { continue }
    foreach ($ln in (Get-Content -LiteralPath $p -Encoding UTF8 -ErrorAction SilentlyContinue)) {
      $t = $ln.Trim().ToLower()
      if ($t -and -not $t.StartsWith('#')) { $ex[$t] = $true }
    }
  }
  return $ex
}

$have = Get-GlobalHave
$excludes = Get-Excludes
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$summary = @()

# ensure curated facebook.txt exists (created once, then only messenger-merge + check)
$fbPath = Join-Path $domDir 'facebook.txt'
if (-not (Test-Path -LiteralPath $fbPath)) {
  $fresh = @()
  foreach ($d in $facebookCurated) {
    if (-not $have.ContainsKey($d) -and -not $excludes.ContainsKey($d)) { $fresh += $d; $have[$d] = 'facebook.txt' }
  }
  [IO.File]::WriteAllLines($fbPath, ($fresh | Sort-Object), $utf8NoBom)
  Write-Host ("[NEW] facebook.txt created (curated infra, {0} entries)." -f $fresh.Count) -ForegroundColor Green
  $summary += 'facebook: created'
}

foreach ($cfg in $sources) {
  $url = $base + $cfg.Up
  try {
    $resp = Invoke-WebRequest -Uri $url -TimeoutSec 20 -UseBasicParsing
    $lines = $resp.Content -split "`n"
  } catch {
    Write-Host ("[FAIL] {0}: download failed ({1}), cache kept." -f $cfg.Id, $_) -ForegroundColor Yellow
    $summary += ($cfg.Id + ': FAIL')
    continue
  }
  $par = Convert-Upstream $lines $cfg
  $local = Join-Path $domDir $cfg.Local
  $cur = @()
  if (Test-Path -LiteralPath $local) {
    $cur = @(Get-Content -LiteralPath $local -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and -not $_.StartsWith('#') })
  }
  $curSet = @{}
  foreach ($c in $cur) { $curSet[$c] = $true }
  $fresh = @()
  $dup = 0; $excl = 0
  foreach ($d in $par.Entries) {
    if ($curSet.ContainsKey($d)) { continue }
    if ($have.ContainsKey($d)) { $dup++; continue }
    if ($excludes.ContainsKey($d)) { $excl++; continue }
    $fresh += $d
  }
  if ($cfg.Mode -eq 'check') {
    Write-Host ("[CHECK] {0}: upstream={1} not-in-local={2} (report only, file untouched)." -f $cfg.Id, $par.Entries.Count, $fresh.Count) -ForegroundColor Cyan
    $summary += ($cfg.Id + ': check')
    continue
  }
  if ($fresh.Count -gt 0) {
    $merged = @($cur + ($fresh | Sort-Object))
    [IO.File]::WriteAllLines($local, $merged, $utf8NoBom)
    foreach ($d in $fresh) { $have[$d] = $cfg.Local }
    Write-Host ("[UPDATED] {0} -> {1}: +{2} (dup={3} excl={4})." -f $cfg.Id, $cfg.Local, $fresh.Count, $dup, $excl) -ForegroundColor Green
    $summary += ($cfg.Id + ": +$($fresh.Count)")
  } else {
    Write-Host ("[OK] {0} -> {1}: unchanged (dup={2} excl={3})." -f $cfg.Id, $cfg.Local, $dup, $excl) -ForegroundColor Gray
    $summary += ($cfg.Id + ': same')
  }
}

Write-Host ""
Write-Host ("Summary: " + ($summary -join ' | '))
Write-Host "Skipped upstream families (documented): google/ads (609 trackers), instagram (follower-spam), steam/twitch (project excludes), ads/win-spy, ru-blocked-all (700k, hostlist-harmful)." -ForegroundColor DarkGray
