# convert-openwrt.ps1 - convert a ZapretExtra preset .bat for Zapret-OpenWRT.
# Opens an Explorer window to pick the source .bat, extracts the pure winws
# argument chain and writes <name>_openwrt.txt next to it.
# Conversion rules:
#  - bat wrapper dropped (echo/chcp/cd/set/call/start/winws.exe prefix);
#  - line continuations (^) joined; one --filter block per output line,
#    --new separators preserved (chain semantics intact);
#  - %BIN% -> /opt/zapret/bin/, %LISTS% -> /opt/zapret/lists/, %ROOT% ->
#    /opt/zapret/, backslashes -> slashes;
#  - %GameFilterTCP/UDP% -> 1024-65535 (narrow to game ports if needed);
#  - --wf-tcp/--wf-udp are WinDivert-only: removed from args, their port
#    lists go to the header (configure the router queue for those ports).
# ASCII-only, PS 5.1 safe.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot

function Pause-End($code) {
  Write-Host ""
  try { Read-Host "Press Enter to exit" | Out-Null } catch { }
  exit $code
}

function Pick-PresetFile {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = Join-Path $rootDir 'Presets'
    $dlg.Filter = 'Preset BAT (*.bat)|*.bat'
    $dlg.Title = 'Select ZapretExtra preset to convert for OpenWRT'
    if ($dlg.ShowDialog() -eq 'OK') { return $dlg.FileName }
    return $null
  } catch {
    Write-Host ("[WARN] File dialog unavailable ({0})." -f $_) -ForegroundColor Yellow
    $p = Read-Host "Enter full path to the preset .bat (empty = cancel)"
    if ($p -and (Test-Path -LiteralPath $p.Trim().Trim('"'))) { return $p.Trim().Trim('"') }
    return $null
  }
}

$src = Pick-PresetFile
if (-not $src) { Write-Host "Cancelled." -ForegroundColor Gray; Pause-End 0 }
Write-Host ("[INFO] Source: {0}" -f $src) -ForegroundColor Cyan

$text = Get-Content -LiteralPath $src -Raw -Encoding UTF8
$m = [regex]::Match($text, '(?i)winws\.exe"?')
if (-not $m.Success) {
  Write-Host "[ERROR] No winws.exe call found in this file." -ForegroundColor Red
  Pause-End 1
}
$args = $text.Substring($m.Index + $m.Length)
# join bat continuations
$args = $args -replace '\^[ \t]*\r?\n[ \t]*', ' '
# normalize whitespace/newlines to single spaces, then split filter chains
$args = ($args -replace '\s+', ' ').Trim()
$blocks = @($args -split '\s*--new\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($blocks.Count -eq 0) {
  Write-Host "[ERROR] Empty argument chain." -ForegroundColor Red
  Pause-End 1
}

$wfTcp = @()
$wfUdp = @()
$hasL7 = $false
$out = @()
foreach ($b in $blocks) {
  $m1 = [regex]::Match($b, '--wf-tcp=([^\s]+)')
  if ($m1.Success) { $wfTcp += ($m1.Groups[1].Value -replace '%GameFilterTCP%', '1024-65535') }
  $m2 = [regex]::Match($b, '--wf-udp=([^\s]+)')
  if ($m2.Success) { $wfUdp += ($m2.Groups[1].Value -replace '%GameFilterUDP%', '1024-65535') }
  if ($b -match '--filter-l7=') { $hasL7 = $true }
  $b = $b -replace '--wf-tcp=[^\s]+', ''
  $b = $b -replace '--wf-udp=[^\s]+', ''
  $b = $b -replace '%BIN%', '/opt/zapret/bin/'
  $b = $b -replace '%LISTS%', '/opt/zapret/lists/'
  $b = $b -replace '%ROOT%', '/opt/zapret/'
  $b = $b -replace '%GameFilterTCP%', '1024-65535'
  $b = $b -replace '%GameFilterUDP%', '1024-65535'
  $b = $b -replace '\\', '/'
  # router NFQWS field rejects quotes ("text cannot contain quotes");
  # unix paths have no spaces, so quotes are simply dropped
  $b = $b -replace '"', ''
  $b = ($b -replace '\s+', ' ').Trim()
  if ($b -ne '') { $out += $b }
}
if ($out.Count -eq 0) {
  Write-Host "[ERROR] Nothing left after conversion." -ForegroundColor Red
  Pause-End 1
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$base = [IO.Path]::GetFileName($src)
# upload checklist: every /opt/zapret/... path actually referenced by ARGS
$needBin = @()
$needLists = @()
foreach ($m in ([regex]::Matches(($out -join ' '), '/opt/zapret/(bin|lists)/(\S+)'))) {
  if ($m.Groups[1].Value -eq 'bin') { $needBin += $m.Groups[2].Value }
  else { $needLists += $m.Groups[2].Value }
}
$needBin = @($needBin | Sort-Object -Unique)
$needLists = @($needLists | Sort-Object -Unique)
$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add('# ZapretExtra -> OpenWRT preset (paste the ARGS section below')
[void]$lines.Add('# into the zapret preset field on your router).')
[void]$lines.Add(('# Source : ' + $base))
[void]$lines.Add(('# Date   : ' + $stamp))
[void]$lines.Add('# Paths  : router layout assumed as /opt/zapret/... ;')
[void]$lines.Add('#          fix bin/lists dirs and upload lists/ + fake .bin files')
[void]$lines.Add('#          if your router uses different paths.')
[void]$lines.Add('# Upload : copy from PC, keep subpaths, do NOT upload')
[void]$lines.Add('#          winws.exe / WinDivert.* / cygwin1.dll / *.bat (Windows-only).')
foreach ($f in $needBin) { [void]$lines.Add(('#          BIN   : ' + $f)) }
foreach ($f in $needLists) { [void]$lines.Add(('#          LISTS : ' + $f)) }
if ($wfTcp.Count -gt 0 -or $wfUdp.Count -gt 0) {
  [void]$lines.Add(('# Divert : TCP ' + (($wfTcp | Sort-Object -Unique) -join ',') + ' / UDP ' + (($wfUdp | Sort-Object -Unique) -join ',')))
  [void]$lines.Add('#          (--wf-* is WinDivert-only and was removed; set up the')
  [void]$lines.Add('#          router packet queue for these ports instead.)')
}
[void]$lines.Add('# GameFilter vars replaced with 1024-65535; narrow if needed.')
if ($hasL7) {
  [void]$lines.Add('# NOTE   : --filter-l7=... is winws-specific; if your router build')
  [void]$lines.Add('#          rejects it, delete that option (keep the rest of the line).')
}
[void]$lines.Add('# ================= ARGS (copy below this line) =================')
for ($i = 0; $i -lt $out.Count; $i++) {
  $suffix = ''
  if ($i -lt $out.Count - 1) { $suffix = ' --new' }
  [void]$lines.Add($out[$i] + $suffix)
}
# step-by-step upload guide (Russian, separate UTF-8 file so this script
# stays ASCII-only and PS 5.1 safe); #-prefixed, router field tolerates it
[void]$lines.Add('#')
[void]$lines.Add('# ============ UPLOAD GUIDE (in Russian, read here) ============')
$guidePath = Join-Path $PSScriptRoot 'openwrt-upload-ru.txt'
if (Test-Path -LiteralPath $guidePath) {
  foreach ($g in (Get-Content -LiteralPath $guidePath -Encoding UTF8)) {
    if ($g.Trim() -eq '') { [void]$lines.Add('#') }
    else { [void]$lines.Add(('# ' + $g)) }
  }
} else {
  [void]$lines.Add('# (guide file utils\openwrt-upload-ru.txt not found)')
}

$dst = Join-Path (Split-Path $src -Parent) ([IO.Path]::GetFileNameWithoutExtension($src) + '_openwrt.txt')
[IO.File]::WriteAllLines($dst, $lines.ToArray(), (New-Object System.Text.UTF8Encoding $false))
Write-Host ""
Write-Host ("[OK] Written: {0} ({1} filter blocks)" -f $dst, $out.Count) -ForegroundColor Green
Write-Host "Upload to router (keep subpaths):" -ForegroundColor Cyan
foreach ($f in $needBin) { Write-Host ("  BIN   /opt/zapret/bin/{0}" -f $f) -ForegroundColor Gray }
foreach ($f in $needLists) { Write-Host ("  LISTS /opt/zapret/lists/{0}" -f $f) -ForegroundColor Gray }
Write-Host "Copy the file content into the zapret preset on your router." -ForegroundColor Cyan
Pause-End 0
