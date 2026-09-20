# convert-stressozz.ps1 — fetches Strategies.md + Strategies_For_Youtube.md from
# StressOzz/Zapret-Manager and builds Windows (winws) presets into Presets\StressOzz.
# v1..v10: TCP/443 strategy + Discord + game blocks. youtube-v01..v27: list-google.
# ASCII-only. Usage: convert-stressozz.ps1 (no args; network required).
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$rootDir = Split-Path $PSScriptRoot
$outDir = Join-Path $rootDir 'Presets\StressOzz'
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$base = 'https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main'

function Get-Md($name) {
  $u = $base + '/' + $name
  Write-Host ('[INFO] downloading ' + $name)
  return (Invoke-WebRequest -Uri $u -TimeoutSec 20 -UseBasicParsing).Content
}

function Get-ArgLines($section) {
  $out = @()
  foreach ($ln in ($section -split "`r?`n")) {
    $t = $ln.Trim()
    if ($t -like '--*') { $out += @($t) }
  }
  return $out
}

function Map-Paths($text) {
  $m = @(
    @('/opt/zapret/files/fake/tls_clienthello_www_google_com.bin', '"%BIN%tls_clienthello\tls_clienthello_www_google_com.bin"'),
    @('/opt/zapret/files/fake/tls_clienthello_vk_com.bin', '"%BIN%tls_clienthello\tls_clienthello_vk_com.bin"'),
    @('/opt/zapret/files/fake/tls_clienthello_gosuslugi_ru.bin', '"%BIN%tls_clienthello\tls_clienthello_gosuslugi_ru.bin"'),
    @('/opt/zapret/files/fake/quic_initial_www_google_com.bin', '"%BIN%quic_initial\quic_initial_www_google_com.bin"'),
    @('/opt/zapret/files/fake/stun.bin', '"%BIN%stun.bin"'),
    @('/opt/zapret/files/fake/4pda.bin', '"%BIN%tls_clienthello\tls_clienthello_4pda_to.bin"'),
    @('/opt/zapret/ipset/zapret-hosts-user-exclude.txt', '"%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt"'),
    @('/opt/zapret/ipset/zapret-hosts-google.txt', '"%LISTS%domains\google.txt"')
  )
  $r = $text
  foreach ($pair in $m) { $r = ([string]$r).Replace($pair[0], $pair[1]) }
  # batch-escape bare "!" (fake-tls=!) as "^!" so arg parsers survive delayed expansion
  $r = [regex]::Replace($r, '=!(?=\s|$)', '=^!')
  return $r
}

$head1 = "@echo off`r`nchcp 65001 > nul`r`n"
function New-Head($title, $withGame) {
  $h = $head1 + ':: ' + $title + " (StressOzz/Zapret-Manager, adapted for winws)`r`n`r`n"
  $h += 'cd /d "%~dp0"' + "`r`n"
  $h += 'for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"' + "`r`n"
  $h += 'call "%ROOT%service.bat" status_zapret' + "`r`n"
  $h += 'call "%ROOT%service.bat" check_updates' + "`r`n"
  if ($withGame) { $h += 'call "%ROOT%service.bat" load_game_filter' + "`r`n" }
  $h += 'call "%ROOT%service.bat" load_user_lists' + "`r`n" + 'echo:' + "`r`n`r`n"
  $h += 'set "BIN=%ROOT%bin\"' + "`r`n" + 'set "LISTS=%ROOT%lists\"' + "`r`n" + 'cd /d %BIN%' + "`r`n`r`n"
  return $h
}

# ---------- v1..v10 ----------
$md = Get-Md 'Strategies.md'
$fences = @([regex]::Matches($md, '(?ms)```\r?\n(.*?)```'))
function Get-FenceAfter($pos) {
  foreach ($f in $fences) {
    if ($f.Index -gt $pos) { return $f }
  }
  return $null
}
$gameArgs = @()
$discBlocks = @()
$di = $md.IndexOf('Discord')
if ($di -ge 0) {
  foreach ($f in $fences) {
    if ($f.Index -gt $di) {
      $al = Get-ArgLines $f.Groups[1].Value
      if ($al.Count -gt 0) { $discBlocks += @( ,$al) }
    }
  }
}
$lastVEnd = 0
$vbodies = @{}
for ($n = 1; $n -le 10; $n++) {
  $h = [regex]::Match($md, '(?m)^#\s*v' + $n + '\s*$')
  if (-not $h.Success) { continue }
  $f = Get-FenceAfter ($h.Index + $h.Length)
  if ($f) {
    $vbodies[$n] = $f.Groups[1].Value
    $fend = $f.Index + $f.Length
    if ($fend -gt $lastVEnd) { $lastVEnd = $fend }
  }
}
if ($lastVEnd -gt 0 -and $di -gt $lastVEnd) {
  foreach ($f in $fences) {
    if ($f.Index -gt $lastVEnd -and ($f.Index + $f.Length) -le $di) {
      $al = Get-ArgLines $f.Groups[1].Value
      if ($al.Count -gt 0) { $gameArgs = $al }
    }
  }
}
Write-Output ('[INFO] v-bodies=' + $vbodies.Count + ' game args=' + $gameArgs.Count + ' discord blocks=' + $discBlocks.Count)
$made = 0
for ($n = 1; $n -le 10; $n++) {
  if (-not $vbodies.ContainsKey($n)) { Write-Output ('[WARN] v' + $n + ' not found'); continue }
  $num = $n
  $sargs = (Get-ArgLines $vbodies[$n]) -join ' '
  if (-not $sargs) { continue }
  $sargs = Map-Paths $sargs
  # own --filter-tcp line is added below; drop the source one to avoid duplicates
  $sargs = [regex]::Replace($sargs, '--filter-tcp=443\s*', '')
  $wf = '--wf-tcp=443,2053,2083,2087,2096,8443,%GameFilterTCP% --wf-udp=19294-19344,50000-50100,%GameFilterUDP%'
  $b = New-Head ('StressOzz v' + $num) $true
  $b += 'start "zapret: v' + $num + ' (StressOzz)" /min "%BIN%winws.exe" ' + $wf + " ^`r`n"
  foreach ($db in $discBlocks) {
    $dl = (Map-Paths ($db -join ' '))
    $b += $dl + " --new ^`r`n"
  }
  $b += '--filter-tcp=443 ' + $sargs + " --new ^`r`n"
  if ($gameArgs.Count -gt 0) {
    $gl = (Map-Paths ($gameArgs -join ' '))
    $gl = $gl -replace '--filter-udp=1024-65535', '--filter-udp=%GameFilterUDP%'
    $b += $gl + "`r`n"
  } else {
    $b = $b.TrimEnd("`r","`n"," ","^") + "`r`n"
  }
  $dst = Join-Path $outDir ('v' + $num + '.bat')
  Set-Content -LiteralPath $dst -Value $b -Encoding UTF8
  $made++
}
Write-Output ('[OK] v-presets made: ' + $made)

# ---------- youtube Yv01..Yv27 ----------
$ymd = Get-Md 'Strategies_For_Youtube.md'
$yparts = [regex]::Split($ymd, '(?m)^#Yv(\d+)\s*$')
$ymade = 0
for ($i = 1; $i -lt $yparts.Count; $i += 2) {
  $num = ([int]$yparts[$i]).ToString('00')
  $yargs = (Get-ArgLines $yparts[$i+1]) -join ' '
  if (-not $yargs) { continue }
  $yargs = Map-Paths $yargs
  $b = New-Head ('StressOzz youtube-v' + $num) $false
  $b += 'start "zapret: youtube-v' + $num + ' (StressOzz)" /min "%BIN%winws.exe" --wf-tcp=443 --wf-udp=443' + " ^`r`n"
  $b += $yargs + "`r`n"
  $dst = Join-Path $outDir ('youtube-v' + $num + '.bat')
  Set-Content -LiteralPath $dst -Value $b -Encoding UTF8
  $ymade++
}
Write-Output ('[OK] youtube presets made: ' + $ymade)
Write-Output 'DONE'
