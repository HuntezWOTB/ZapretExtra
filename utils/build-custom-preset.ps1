# build-custom-preset.ps1 v2 — per-server family presets + hybrid preset
# Input : utils\"test results"\test_results_*.json (from test zapret.ps1, standard tests)
# Output: preset-aws-only / preset-cloudflare-only / preset-aws-cloudflare (AUTO ts).bat
#         + custom (AUTO ts).bat (full hybrid) + alive IP lists in lists\
# ASCII-only (PS 5.1 safe without BOM).

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$listsDir = Join-Path $rootDir "lists"
$resultsDir = Join-Path $PSScriptRoot "test results"

function Pause-Exit($code) {
  Write-Host ""
  Read-Host "Press Enter to exit" | Out-Null
  exit $code
}

if (-not (Test-Path $resultsDir)) {
  Write-Host "[ERROR] No results dir. Run tests first (service.bat -> Run Tests -> Standard)." -ForegroundColor Red
  Pause-Exit 1
}
$jsonFiles = Get-ChildItem -LiteralPath $resultsDir -Filter "test_results_*.json" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
if (-not $jsonFiles -or $jsonFiles.Count -eq 0) {
  Write-Host "[ERROR] No JSON results. Re-run tests (test script now saves .json)." -ForegroundColor Red
  Pause-Exit 1
}
Write-Host "Available results (type | profile | best | date):" -ForegroundColor Cyan
$show = [Math]::Min(10, $jsonFiles.Count)
for ($i = 0; $i -lt $show; $i++) {
  $hint = $jsonFiles[$i].Name
  try {
    $h = Get-Content -LiteralPath $jsonFiles[$i].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $hp = '?'; if ($h.PSObject.Properties['profile']) { $hp = $h.profile }
    $hb = '?'; if ($h.best) { $hb = $h.best }
    $hint = ('{0} | {1} | {2} | {3}' -f $jsonFiles[$i].Name, $h.testType, $hp, $hb)
  } catch { }
  Write-Host ("  [{0}] {1}" -f ($i + 1), $hint) -ForegroundColor Gray
}
Write-Host "Hint: no good file? Run tests first (manager item 6): pick Standard or" -ForegroundColor DarkGray
Write-Host "Combined + the profile you need (Discord/CF/AWS/...), then build again." -ForegroundColor DarkGray
$sel = Read-Host ("Select file (1-{0}, Enter = latest)" -f $show)
$idx = 0
if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $show) { $idx = [int]$sel - 1 }
$jsonFile = $jsonFiles[$idx]
Write-Host ("[INFO] Using: {0}" -f $jsonFile.Name) -ForegroundColor Cyan
$data = Get-Content -LiteralPath $jsonFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
if ($data.testType -ne 'standard' -and $data.testType -ne 'combined') {
  Write-Host ("[ERROR] Result type is '{0}'. Builder needs Standard or Combined tests." -f $data.testType) -ForegroundColor Red
  Pause-Exit 1
}
# Combined runs carry dpi entries too — builder uses standard entries only
$stdEntries = @($data.results | Where-Object { $_.type -eq 'standard' })
if ($stdEntries.Count -eq 0) {
  Write-Host "[ERROR] No standard entries in this result file." -ForegroundColor Red
  Pause-Exit 1
}
if ($data.PSObject.Properties['profile']) {
  Write-Host ("[INFO] Test profile: {0}" -f $data.profile) -ForegroundColor Cyan
}
if ($data.PSObject.Properties['respLimit']) {
  Write-Host ("[INFO] Limits used: response >{0}s = TIMEENDED, ping >{1}ms = SLOW" -f $data.respLimit, $data.pingLimit) -ForegroundColor Cyan
}
# per-config DPI penalty (LIKELY_BLOCKED + FAIL over dpi entries; 0 if none)
$cfgBlocked = @{}
foreach ($e in @($data.results | Where-Object { $_.type -eq 'dpi' })) {
  $n = 0
  foreach ($r in $e.results) {
    foreach ($ln in @($r.Lines)) {
      if ($ln.Status -eq 'LIKELY_BLOCKED' -or $ln.Status -eq 'FAIL') { $n++ }
    }
  }
  $cfgBlocked[$e.config] = $n
}

# --- targets.txt map: Name -> Url / PingIp ---
$targetDefs = @{}
$targetsFile = Join-Path $PSScriptRoot "targets.txt"
if (Test-Path $targetsFile) {
  foreach ($ln in (Get-Content $targetsFile -Encoding UTF8)) {
    if ($ln -match '^\s*(\w+)\s*=\s*"(.+)"\s*$') {
      $n = $matches[1]; $v = $matches[2]
      if ($v -like 'PING:*') { $targetDefs[$n] = [PSCustomObject]@{ IsPing = $true; Ip = ($v -replace '^PING:\s*',''); Host = $null } }
      else {
        $h = $v -replace '^https?://','' -replace '/.*$',''
        $targetDefs[$n] = [PSCustomObject]@{ IsPing = $false; Ip = $null; Host = $h }
      }
    }
  }
}

function Get-TargetGroup($name) {
  if ($name -like 'Discord*') { return 'discord' }
  if ($name -like 'YouTube*') { return 'youtube' }
  if ($name -like 'GoogleMain' -or $name -like 'GoogleGstatic') { return 'google' }
  if ($name -like 'Instagram*') { return 'instagram' }
  if ($name -like 'X*' -or $name -like 'Twitter*' -or $name -like 'Twimg*') { return 'x' }
  if ($name -like 'Cloudflare*' -or $name -like 'CFPing*') { return 'cloudflare' }
  if ($name -like 'Aws*') { return 'aws' }
  return 'other'
}
$groupClasses = @{
  discord    = @('udp-discord', 'tcp-discord-media')
  google     = @('tcp-google', 'tcp-general', 'udp443-general')
  youtube    = @('tcp-google', 'tcp-general', 'udp443-general')
  instagram  = @('tcp-general', 'udp443-general')
  x          = @('tcp-general', 'udp443-general')
  cloudflare = @('tcp-cloudflare', 'udp-cloudflare', 'tcp-general')
  aws        = @('tcp-aws', 'udp-aws')
  other      = @()
}
# family TCP class used for per-domain lines:
$groupTcpClass = @{ discord = 'tcp-discord-media'; google = 'tcp-google'; youtube = 'tcp-google'; instagram = 'tcp-general'; x = 'tcp-general'; cloudflare = 'tcp-cloudflare'; aws = 'tcp-aws'; other = 'tcp-general' }

# loss% from "12 ms, loss 25%" (plain "12 ms" = 0, "Timeout" = 100)
function Get-Loss($pingResult) {
  if ($pingResult -eq 'Timeout') { return 100 }
  $m = [regex]::Match($pingResult, 'loss\s+(\d+)%')
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return 0
}

# --- per-target scores (OK, ERR incl. TIMEENDED, loss, ping, DPI-blocked) ---
$scores = @{}   # target -> config -> {OK, ERR, Loss, PingOk}
foreach ($entry in $stdEntries) {
  $cfg = $entry.config
  foreach ($r in $entry.results) {
    $t = $r.Name
    if (-not $scores.ContainsKey($t)) { $scores[$t] = @{} }
    $ok = 0; $err = 0
    foreach ($tok in @($r.HttpTokens)) {
      if ($tok -match 'TIMEENDED') { $err++ }
      elseif ($tok -match 'OK') { $ok++ }
      elseif ($tok -match 'ERROR|SSL') { $err++ }
    }
    $pingOk = ($r.PingResult -ne 'Timeout' -and $r.PingResult -ne 'n/a' -and $r.PingResult -notlike 'SLOW*')
    $scores[$t][$cfg] = [PSCustomObject]@{ OK = $ok; ERR = $err; Loss = (Get-Loss $r.PingResult); PingOk = $pingOk }
  }
}
$targetWinners = @{}
foreach ($t in $scores.Keys) {
  $best = $null; $bOk = -1; $bErr = 999; $bPing = $false; $bLoss = 999; $bBlk = 999
  foreach ($cfg in ($scores[$t].Keys | Sort-Object)) {
    $s = $scores[$t][$cfg]
    $blk = 0
    if ($cfgBlocked.ContainsKey($cfg)) { $blk = $cfgBlocked[$cfg] }
    $better = $false
    if ($s.OK -gt $bOk) { $better = $true }
    elseif ($s.OK -eq $bOk -and $s.ERR -lt $bErr) { $better = $true }
    elseif ($s.OK -eq $bOk -and $s.ERR -eq $bErr -and $s.PingOk -and -not $bPing) { $better = $true }
    elseif ($s.OK -eq $bOk -and $s.ERR -eq $bErr -and $s.PingOk -eq $bPing -and $s.Loss -lt $bLoss) { $better = $true }
    elseif ($s.OK -eq $bOk -and $s.ERR -eq $bErr -and $s.PingOk -eq $bPing -and $s.Loss -eq $bLoss -and $blk -lt $bBlk) { $better = $true }
    if ($better) { $best = $cfg; $bOk = $s.OK; $bErr = $s.ERR; $bPing = $s.PingOk; $bLoss = $s.Loss; $bBlk = $blk }
  }
  $targetWinners[$t] = $best
}

# --- working vs failed servers ---
$workingDomains = @{ cloudflare = @(); aws = @() }   # names
$workingIps = @{ cloudflare = @(); aws = @() }       # ip strings
$failed = @()
foreach ($t in ($scores.Keys | Sort-Object)) {
  $g = Get-TargetGroup $t
  if ($g -ne 'cloudflare' -and $g -ne 'aws') { continue }
  $def = $null
  if ($targetDefs.ContainsKey($t)) { $def = $targetDefs[$t] }
  if ($def -and $def.IsPing) {
    $nCfg = $scores[$t].Keys.Count
    $nOk = 0
    foreach ($cfg in $scores[$t].Keys) { if ($scores[$t][$cfg].PingOk) { $nOk++ } }
    if ($nOk * 2 -ge $nCfg) { $workingIps[$g] += @($def.Ip) }
    else { $failed += @($t + ' (ping ' + $nOk + '/' + $nCfg + ')') }
  } else {
    $w = $targetWinners[$t]
    $s = $scores[$t][$w]
    if ($s.OK -gt 0) {
      $h = $null
      if ($def) { $h = $def.Host }
      if (-not $h) { $h = $t }
      $workingDomains[$g] += @([PSCustomObject]@{ Target = $t; Host = $h; Winner = $w })
    } else {
      $failed += @($t + ' (no HTTP OK in ' + $w + ')')
    }
  }
}

Write-Host ""
Write-Host "=== WORKING SERVERS ===" -ForegroundColor Cyan
foreach ($g in @('cloudflare', 'aws')) {
  Write-Host ("  [{0}] domains: {1}, ips: {2}" -f $g, $workingDomains[$g].Count, $workingIps[$g].Count) -ForegroundColor Green
  foreach ($d in $workingDomains[$g]) { Write-Host ("    DOMAIN {0} ({1}) -> {2}" -f $d.Target, $d.Host, $d.Winner) -ForegroundColor Gray }
  foreach ($ip in $workingIps[$g]) { Write-Host ("    IP     {0}" -f $ip) -ForegroundColor Gray }
}
Write-Host "=== FAILED / SKIPPED ===" -ForegroundColor Yellow
if ($failed.Count -eq 0) { Write-Host "  (none)" -ForegroundColor Gray }
else { foreach ($f in $failed) { Write-Host ("  " + $f) -ForegroundColor Yellow } }

# --- class vote winners (for hybrid + alive-file lines) ---
$classVotes = @{}
foreach ($t in $targetWinners.Keys) {
  foreach ($c in $groupClasses[(Get-TargetGroup $t)]) {
    if (-not $classVotes.ContainsKey($c)) { $classVotes[$c] = @{} }
    $w = $targetWinners[$t]
    if (-not $classVotes[$c].ContainsKey($w)) { $classVotes[$c][$w] = 0 }
    $classVotes[$c][$w]++
  }
}
$classWinners = @{}
foreach ($c in $classVotes.Keys) {
  $top = $null; $n = -1
  foreach ($cfg in ($classVotes[$c].Keys | Sort-Object)) {
    if ($classVotes[$c][$cfg] -gt $n) { $n = $classVotes[$c][$cfg]; $top = $cfg }
  }
  $classWinners[$c] = $top
}

# --- .bat parsing helpers ---
function Get-FilterLine($text, $class) {
  $lines = $text -split "`r?`n"
  foreach ($ln in $lines) {
    $t = $ln.Trim()
    switch ($class) {
      'udp-discord'       { if ($t -match '--filter-udp=19294-19344,50000-50100' -and $t -match 'filter-l7=discord') { return $ln } }
      'tcp-discord-media' { if ($t -match 'discord\.media') { return $ln } }
      'tcp-google'        { if ($t -match '--filter-tcp=443 --hostlist=' -and $t -match 'domains\\google') { return $ln } }
      'tcp-general'       { if ($t -match '--filter-tcp=80,443 ' -and $t -match 'domains\\general') { return $ln } }
      'udp443-general'    { if ($t -match '--filter-udp=443' -and $t -match 'domains\\general') { return $ln } }
      'udp-ipset-all'     { if ($t -match '--filter-udp=443' -and $t -match 'ipsets\\all\.txt') { return $ln } }
      'tcp-ipset-all'     { if ($t -match '--filter-tcp=80,443,8443' -and $t -match 'ipsets\\all\.txt') { return $ln } }
      'udp-cloudflare'    { if ($t -match 'ipsets\\cloudflare' -and $t -match '--filter-udp=443') { return $ln } }
      'tcp-cloudflare'    { if ($t -match 'ipsets\\cloudflare' -and $t -match '--filter-tcp=') { return $ln } }
      'udp-aws'           { if ($t -match 'ipsets\\amazon' -and $t -match '--filter-udp=') { return $ln } }
      'tcp-aws'           { if ($t -match 'ipsets\\amazon' -and $t -match '--filter-tcp=') { return $ln } }
      'tcp-game'          { if ($t -match '--filter-tcp=%GameFilterTCP%') { return $ln } }
      'udp-game'          { if ($t -match '--filter-udp=%GameFilterUDP%') { return $ln } }
    }
  }
  return $null
}
function Get-Desync($line) {
  $m = [regex]::Match($line, '(--dpi-desync=.*)$')
  if (-not $m.Success) { return $null }
  $d = $m.Groups[1].Value.Trim()
  $d = $d -replace '\s*\^?\s*$', ''
  $d = $d -replace '\s*--new\s*$', ''
  return $d.Trim()
}
function Set-Desync($line, $desync) {
  $m = [regex]::Match($line, '^(.*?)--dpi-desync=.*$')
  if (-not $m.Success) { return $line }
  $head = $m.Groups[1].Value
  $tail = ''
  if ($line.TrimEnd() -match '\^$') { $tail = ' --new ^' }
  elseif ($line -match '--new') { $tail = ' --new' }
  return ($head + $desync + $tail)
}
$batCache = @{}
function Find-BatPath($name) {
  # absolute name from test results may be "Author\file.bat" (Presets) or plain (root)
  $p1 = Join-Path $rootDir $name
  if (Test-Path -LiteralPath $p1) { return $p1 }
  $p2 = Join-Path (Join-Path $rootDir 'Presets') $name
  if (Test-Path -LiteralPath $p2) { return $p2 }
  $leaf = Split-Path $name -Leaf
  $hit = Get-ChildItem -LiteralPath (Join-Path $rootDir 'Presets') -Filter $leaf -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { return $hit.FullName }
  return $null
}
function Get-BatText($name) {
  if (-not $batCache.ContainsKey($name)) {
    $p = Find-BatPath $name
    if ($p) { $batCache[$name] = Get-Content -LiteralPath $p -Raw -Encoding UTF8 }
    else { $batCache[$name] = $null }
  }
  return $batCache[$name]
}
function Get-ClassDesync($configName, $class, $fallbackDesync) {
  $t = Get-BatText $configName
  if ($t) {
    $ln = Get-FilterLine $t $class
    if ($ln) {
      $d = Get-Desync $ln
      if ($d) { return $d }
    }
  }
  return $fallbackDesync
}

$templateName = $data.best
if (-not (Get-BatText $templateName)) {
  Write-Host ("[WARN] Template '{0}' missing, using general.bat" -f $templateName) -ForegroundColor Yellow
  $templateName = 'general.bat'
}
$fallbackTcp = Get-ClassDesync $templateName 'tcp-general' '--dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig'
$fallbackUdp = Get-ClassDesync $templateName 'udp443-general' '--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin"'
$fallbackAwsUdp = Get-ClassDesync $templateName 'udp-aws' '--dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=10 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp="%BIN%quic_initial_www_google_com.bin" --dpi-desync-cutoff=n2'
$fallbackAwsTcp = Get-ClassDesync $templateName 'tcp-aws' '--dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig'

# class winners with fallback to template
$cfTcpW = $templateName; if ($classWinners.ContainsKey('tcp-cloudflare')) { $cfTcpW = $classWinners['tcp-cloudflare'] }
$cfUdpW = $templateName; if ($classWinners.ContainsKey('udp-cloudflare')) { $cfUdpW = $classWinners['udp-cloudflare'] }
$awsTcpW = $templateName; if ($classWinners.ContainsKey('tcp-aws')) { $awsTcpW = $classWinners['tcp-aws'] }
$awsUdpW = $templateName; if ($classWinners.ContainsKey('udp-aws')) { $awsUdpW = $classWinners['udp-aws'] }
$cfTcpD = Get-ClassDesync $cfTcpW 'tcp-cloudflare' $fallbackTcp
$cfUdpD = Get-ClassDesync $cfUdpW 'udp-cloudflare' $fallbackUdp
$awsTcpD = Get-ClassDesync $awsTcpW 'tcp-aws' $fallbackAwsTcp
$awsUdpD = Get-ClassDesync $awsUdpW 'udp-aws' $fallbackAwsUdp

# --- alive IP files (working only; fallback to full lists if empty) ---
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
function Write-AliveFile($path, $ips, $fullSrc) {
  if ($ips.Count -gt 0) {
    $out = @()
    foreach ($ip in ($ips | Sort-Object -Unique)) { $out += @($ip + '/32') }
    $out | Set-Content -LiteralPath $path -Encoding UTF8
    return 'alive(' + $ips.Count + ')'
  } else {
    Copy-Item -LiteralPath $fullSrc -Destination $path -Force
    return 'FULL-FALLBACK'
  }
}
$cfAlive = Join-Path $listsDir "ipsets\cloudflare-alive.txt"
$awsAlive = Join-Path $listsDir "ipsets\amazon-alive.txt"
$cfMode = Write-AliveFile $cfAlive $workingIps['cloudflare'] (Join-Path $listsDir "ipsets\cloudflare.txt")
$awsMode = Write-AliveFile $awsAlive $workingIps['aws'] (Join-Path $listsDir "ipsets\amazon.txt")
Write-Host ""
Write-Host ("[INFO] {0} : {1}" -f (Split-Path $cfAlive -Leaf), $cfMode) -ForegroundColor Cyan
Write-Host ("[INFO] {0} : {1}" -f (Split-Path $awsAlive -Leaf), $awsMode) -ForegroundColor Cyan

# --- family .bat builder (outputs to Presets\Custom, ROOT-relative) ---
$customDir = Join-Path $rootDir 'Presets\Custom'
if (-not (Test-Path -LiteralPath $customDir)) { New-Item -ItemType Directory -Path $customDir | Out-Null }
$excl = '--hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt"'
$awsUpdate = @'
:: AWS list auto-update
set "AWS_LIST=%ROOT%lists\ipsets\amazon.txt"
set "AWS_BEFORE=0"
if exist "%AWS_LIST%" (
    for /f %%A in ('find /c /v "" ^< "%AWS_LIST%"') do set AWS_BEFORE=%%A
)
echo [INFO] AWS list: %AWS_BEFORE% entries, updating...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%update-aws.ps1"
if %ERRORLEVEL% neq 0 (
    echo [WARN] AWS update failed, using cached list.
) else (
    echo [INFO] AWS list update finished.
)
set "AWS_BEFORE="
:: end AWS update

'@
function New-FamilyBat($fileName, $title, $wfTcp, $wfUdp, $filterLines, $withAwsUpdate, $srcTag) {
  $head = "@echo off`r`nchcp 65001 > nul`r`n:: {0} built from {1} | {2}`r`n`r`ncd /d `"%~dp0`"`r`n" -f $title, $jsonFile.Name, $srcTag
  $head += 'for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"' + "`r`n"
  $head += 'call "%ROOT%service.bat" status_zapret' + "`r`n" + 'call "%ROOT%service.bat" check_updates' + "`r`necho:`r`n"
  if ($withAwsUpdate) { $head += $awsUpdate }
  $head += "set `"BIN=%ROOT%bin\`"`r`nset `"LISTS=%ROOT%lists\`"`r`ncd /d %BIN%`r`n`r`n"
  $head += 'start "zapret: ' + $title + '" /min "%BIN%winws.exe" --wf-tcp=' + $wfTcp + ' --wf-udp=' + $wfUdp + " ^`r`n"
  $body = ""
  for ($i = 0; $i -lt $filterLines.Count; $i++) {
    $suffix = " --new ^`r`n"
    if ($i -eq $filterLines.Count - 1) { $suffix = "`r`n" }
    $body += ($filterLines[$i] + $suffix)
  }
  Set-Content -LiteralPath (Join-Path $customDir $fileName) -Value ($head + $body) -Encoding UTF8
}

# per-domain lines (point presets, winner strategy each)
function New-DomainLines($group) {
  $cls = $groupTcpClass[$group]
  $arr = @()
  foreach ($d in $workingDomains[$group]) {
    $dd = Get-ClassDesync $d.Winner $cls $fallbackTcp
    $arr += @('--filter-tcp=443 --hostlist-domains=' + $d.Host + ' ' + $dd)
  }
  return $arr
}

# AWS-ONLY
$awsLines = @(New-DomainLines 'aws')
$awsLines += @('--filter-udp=443 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsUdpD)
$awsLines += @('--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsTcpD)
$awsLines += @('--filter-udp=444-65535 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsUdpD)
$awsLines += @('--filter-tcp=444-65535 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsTcpD)
New-FamilyBat ("preset-aws-only (AUTO " + $stamp + ").bat") "aws-only" "80,443,444-65535" "443,444-65535" $awsLines $true "aws-domains+alive"

# CLOUDFLARE-ONLY
$cfLines = @(New-DomainLines 'cloudflare')
$cfLines += @('--filter-udp=443 --ipset="%LISTS%ipsets\cloudflare-alive.txt" ' + $excl + ' ' + $cfUdpD)
$cfLines += @('--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\cloudflare-alive.txt" ' + $excl + ' ' + $cfTcpD)
New-FamilyBat ("preset-cloudflare-only (AUTO " + $stamp + ").bat") "cf-only" "80,443,8443" "443" $cfLines $false "cf-domains+alive"

# COMBINED
$combo = @()
$combo += @(New-DomainLines 'cloudflare')
$combo += @('--filter-udp=443 --ipset="%LISTS%ipsets\cloudflare-alive.txt" ' + $excl + ' ' + $cfUdpD)
$combo += @('--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\cloudflare-alive.txt" ' + $excl + ' ' + $cfTcpD)
$combo += @(New-DomainLines 'aws')
$combo += @('--filter-udp=443 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsUdpD)
$combo += @('--filter-tcp=80,443,8443 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsTcpD)
$combo += @('--filter-udp=444-65535 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsUdpD)
$combo += @('--filter-tcp=444-65535 --ipset="%LISTS%ipsets\amazon-alive.txt" ' + $excl + ' ' + $awsTcpD)
New-FamilyBat ("preset-aws-cloudflare (AUTO " + $stamp + ").bat") "aws-cf" "80,443,8443,444-65535" "443,444-65535" $combo $true "cf+aws-domains+alive"

Write-Host ""
Write-Host "[OK] Family presets written:" -ForegroundColor Green
Write-Host ("  preset-aws-only (AUTO {0}).bat  [{1} domain lines]" -f $stamp, $workingDomains['aws'].Count) -ForegroundColor Gray
Write-Host ("  preset-cloudflare-only (AUTO {0}).bat  [{1} domain lines]" -f $stamp, $workingDomains['cloudflare'].Count) -ForegroundColor Gray
Write-Host ("  preset-aws-cloudflare (AUTO {0}).bat" -f $stamp) -ForegroundColor Gray

# --- full hybrid custom preset (as before) ---
$templateText = Get-BatText $templateName
$replaced = @()
foreach ($c in $classWinners.Keys) {
  $winner = $classWinners[$c]
  if ($winner -eq $templateName) { continue }
  $wText = Get-BatText $winner
  if (-not $wText) { continue }
  $wLine = Get-FilterLine $wText $c
  $tLine = Get-FilterLine $templateText $c
  if (-not $wLine -or -not $tLine) { continue }
  $wDesync = Get-Desync $wLine
  if (-not $wDesync) { continue }
  $newLine = Set-Desync $tLine $wDesync
  if ($newLine -ne $tLine) {
    $templateText = $templateText.Replace($tLine, $newLine)
    $replaced += @($c + ': ' + $winner)
  }
}
$outName = "custom (AUTO " + $stamp + ").bat"
if ($templateText -match '(?s)^(@echo off\r?\nchcp 65001 > nul\r?\n)') {
  $templateText = $templateText -replace '(?s)^(@echo off\r?\nchcp 65001 > nul\r?\n)', ('$1:: AUTO-BUILT from ' + $jsonFile.Name + ' | template=' + $templateName + "`r`n")
}
Set-Content -LiteralPath (Join-Path $customDir $outName) -Value $templateText -Encoding UTF8
Write-Host ("[OK] Hybrid preset: {0}  (replacements: {1})" -f $outName, $replaced.Count) -ForegroundColor Green
foreach ($r in $replaced) { Write-Host ("  " + $r) -ForegroundColor DarkGray }
Write-Host "Next: retest the new preset(s) via manager item 6 (they are picked up" -ForegroundColor Cyan
Write-Host "automatically), then install the winner as a service (manager item 2)." -ForegroundColor Cyan
Pause-Exit 0
