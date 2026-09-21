# live-pick.ps1 v1 (ZapretExtra 1.01 LIVE) - dynamic preset picker over live targets
# Input : utils\live-targets.txt (from watch-app.ps1) [+ live-capture.json for ports/IPs]
# Output: utils\live results\live_results_*.txt + *.json (all attempts, ranked)
#         Presets\Custom\preset-point-*.bat + lists\ipsets\point-*.txt (on demand)
# ASCII-only, PS 5.1 safe.
# Logic: semi-auto hybrid. Auto oracle = curl + ping + tcp-connect timing.
#        User oracle  = score 1..3 after trying game/site live (optional, Enter = skip).

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$utilsDir = $PSScriptRoot
$listsDir = Join-Path $rootDir "lists"
$resultsDir = Join-Path $utilsDir "live results"
if (-not (Test-Path -LiteralPath $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }
$liveTargetsFile = Join-Path $utilsDir "live-targets.txt"
$liveCaptureFile = Join-Path $utilsDir "live-capture.json"
$targetDir = $rootDir

function Pause-End($code) {
  Write-Host ""
  try { Read-Host "Press Enter to exit" | Out-Null } catch { }
  exit $code
}
function Wait-WinwsReady {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt 6000) {
    if (Get-Process -Name "winws" -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 400; return $true }
    Start-Sleep -Milliseconds 200
  }
  return $false
}
function Stop-Zapret { Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force }
function Get-WinwsSnapshot {
  try { return Get-CimInstance Win32_Process -Filter "Name='winws.exe'" | Select-Object ProcessId, CommandLine, ExecutablePath } catch { return @() }
}
function Restore-WinwsSnapshot($snapshot) {
  if (-not $snapshot -or $snapshot.Count -eq 0) { return }
  $current = @()
  try { $current = (Get-WinwsSnapshot).CommandLine } catch { $current = @() }
  Write-Host "[INFO] Restoring previous winws instance(s)..." -ForegroundColor DarkGray
  foreach ($p in $snapshot) {
    if (-not $p.ExecutablePath) { continue }
    if ($current -and $current -contains $p.CommandLine) { continue }
    $exe = $p.ExecutablePath
    $pargs = $null
    if ($p.CommandLine -match '^\s*"[^"]*"\s*(.*)$') { $pargs = $matches[1].Trim() }
    elseif ($p.CommandLine -and $p.CommandLine.StartsWith($exe, [StringComparison]::OrdinalIgnoreCase)) { $pargs = $p.CommandLine.Substring($exe.Length).Trim() }
    elseif ($p.CommandLine -match '^\s*\S+\s*(.*)$') { $pargs = $matches[1].Trim() }
    if (-not $pargs) { Write-Host "[WARN] skip restore (no args): $exe" -ForegroundColor Yellow; continue }
    try { Start-Process -FilePath $exe -ArgumentList $pargs -WorkingDirectory (Split-Path $exe -Parent) -WindowStyle Minimized | Out-Null }
    catch { Write-Host ("[WARN] restore failed: {0}" -f $_) -ForegroundColor Yellow }
  }
}
function New-OrderedDict { New-Object System.Collections.Specialized.OrderedDictionary }
function Add-OrSet($dict, $key, $val) { if ($dict.Contains($key)) { $dict[$key] = $val } else { $dict.Add($key, $val) } }
function Convert-Target($Name, $Value) {
  if ($Value -like "PING:*") {
    $ping = $Value -replace '^PING:\s*', ''
    return (New-Object PSObject -Property @{ Name=$Name; Url=$null; PingTarget=$ping })
  }
  $url = $Value
  $pingTarget = $url -replace "^https?://", "" -replace "/.*$", ""
  return (New-Object PSObject -Property @{ Name=$Name; Url=$url; PingTarget=$pingTarget })
}

# --- checks ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "[ERROR] Run as Administrator." -ForegroundColor Red
  Pause-End 1
}
if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
  Write-Host "[ERROR] curl.exe not found." -ForegroundColor Red
  Pause-End 1
}
if (-not (Test-Path -LiteralPath $liveTargetsFile)) {
  Write-Host "[ERROR] No live-targets.txt. Run step 1 (watch-app) first." -ForegroundColor Red
  Pause-End 1
}

# --- load live targets ---
$rawTargets = New-OrderedDict
Get-Content -LiteralPath $liveTargetsFile -Encoding UTF8 | ForEach-Object {
  if ($_ -match '^\s*(\w+)\s*=\s*"(.+)"\s*$') { Add-OrSet -dict $rawTargets -key $matches[1] -val $matches[2] }
}
if ($rawTargets.Count -eq 0) { Write-Host "[ERROR] live-targets.txt empty." -ForegroundColor Red; Pause-End 1 }
$targetList = @()
foreach ($k in $rawTargets.Keys) { $targetList += Convert-Target -Name $k -Value $rawTargets[$k] }
Write-Host ("[INFO] Live targets: {0}" -f $targetList.Count) -ForegroundColor Cyan
foreach ($t in $targetList) {
  if ($t.Url) { Write-Host ("  {0} -> {1}" -f $t.Name, $t.Url) -ForegroundColor Gray }
  else { Write-Host ("  {0} -> PING {1}" -f $t.Name, $t.PingTarget) -ForegroundColor Gray }
}

# --- load live capture ports (for point preset + tcp oracle) ---
$livePorts = @()  # @{Ip, Port, Proto}
try {
  if (Test-Path -LiteralPath $liveCaptureFile) {
    $cap = Get-Content -LiteralPath $liveCaptureFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($e in @($cap.endpoints)) {
      if ($e.port -gt 0) { $livePorts += @{ Ip=[string]$e.ip; Port=[int]$e.port; Proto=[string]$e.proto } }
    }
  }
} catch { }

# --- preset list ---
$allBat = Get-ChildItem -Path $targetDir -Filter "*.bat" -Recurse | Where-Object {
  $_.Name -notlike "service*" -and $_.Name -notlike "BUILD-*" -and $_.Name -notlike "ZAPRET*" -and
  $_.DirectoryName -notlike "*utils*" -and $_.FullName -notlike "*\Apps\*" -and $_.FullName -notlike "*\live*"
} | Sort-Object { [Regex]::Replace($_.FullName, "(\d+)", { $args[0].Value.PadLeft(8, "0") }) }
if (-not $allBat -or $allBat.Count -eq 0) { Write-Host "[ERROR] No presets found." -ForegroundColor Red; Pause-End 1 }
Write-Host ("[INFO] Presets total: {0}" -f $allBat.Count) -ForegroundColor Cyan

Write-Host ""
Write-Host "Select run mode:" -ForegroundColor Cyan
Write-Host "  [1] Quick top-12 (recommended for games)" -ForegroundColor Gray
Write-Host "  [2] Pick manually (numbers/ranges, e.g. 1,5-10)" -ForegroundColor Gray
Write-Host "  [3] All presets (long!)" -ForegroundColor Gray
$mode = Read-Host "Enter 1-3 (default 1)"
if ($mode -ne '2' -and $mode -ne '3') { $mode = '1' }

$batFiles = @()
if ($mode -eq '3') { $batFiles = @($allBat) }
elseif ($mode -eq '2') {
  for ($i = 0; $i -lt $allBat.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i+1), $allBat[$i].FullName.Replace($targetDir,'')) -ForegroundColor Gray }
  $sel = Read-Host "Enter numbers/ranges or 0=all"
  if ($sel.Trim() -eq '0') { $batFiles = @($allBat) }
  else {
    $idx = @()
    foreach ($part in ($sel -split '[,\s]+' | Where-Object { $_ -match '^\d+(-\d+)?$' })) {
      if ($part -match '^(\d+)-(\d+)$') {
        $s=[int]$matches[1]; $e=[int]$matches[2]
        if ($s -gt $e) { continue }
        for ($k=[Math]::Max($s,1); $k -le [Math]::Min($e,$allBat.Count); $k++) { $idx += $k }
      } else { $n=[int]$part; if ($n -ge 1 -and $n -le $allBat.Count) { $idx += $n } }
    }
    $idx = @($idx | Sort-Object -Unique)
    if ($idx.Count -eq 0) { Write-Host "[ERROR] nothing selected." -ForegroundColor Red; Pause-End 1 }
    $batFiles = @($idx | ForEach-Object { $allBat[$_ - 1] })
  }
} else {
  # quick top-12: prefer known-good diverse strategies if present, else first 12
  $prefer = @('general.bat','general (ALT9).bat','general (ALT).bat','general (FAKE TLS AUTO).bat','general (SIMPLE FAKE).bat','v1.bat','v10.bat','v6.bat','youtube-v01.bat')
  $picked = @()
  foreach ($p in $prefer) {
    $hit = @($allBat | Where-Object { $_.Name -eq $p })
    if ($hit.Count -gt 0) { $picked += $hit[0] }
    if ($picked.Count -ge 12) { break }
  }
  foreach ($b in $allBat) {
    if ($picked.Count -ge 12) { break }
    if ($picked -notcontains $b) { $picked += $b }
  }
  $batFiles = @($picked)
}
Write-Host ("[INFO] Will test {0} preset(s)." -f $batFiles.Count) -ForegroundColor Cyan

Write-Host ""
Write-Host "User scoring: after each preset you get time to try game/site live." -ForegroundColor Yellow
Write-Host "Rate: [1]=bad [2]=ok [3]=great, Enter=skip (auto metrics only)." -ForegroundColor Yellow
$askUser = Read-Host "Ask user score each time? (Y/n, default Y)"
if ($askUser -match '^[nN]') { $askUser = $false } else { $askUser = $true }
# Soak time is configurable: e.g. 15s quick check ("did images/textures load?") or 30-60s full.
$soakSec = 20
if ($askUser) {
  $s = Read-Host "Seconds to try game/site before rating each preset (0-120, default 20; 15 = quick check)"
  if ($s -match '^\d+$' -and [int]$s -ge 0 -and [int]$s -le 120) { $soakSec = [int]$s }
  Write-Host ("[INFO] Soak time: {0}s per preset." -f $soakSec) -ForegroundColor Cyan
}

$svc = Get-Service -Name "zapret" -ErrorAction SilentlyContinue
if ($svc) {
  Write-Host "[WARN] Service 'zapret' installed. Tests will STOP winws temporarily and restore after." -ForegroundColor Yellow
  $c = Read-Host "Continue? (Y/N, default N)"
  if ($c -ne 'Y' -and $c -ne 'y') { Pause-End 0 }
}

$env:NO_UPDATE_CHECK = "1"
$originalWinws = Get-WinwsSnapshot
$attempts = @()
$num = 0

try {
  foreach ($file in $batFiles) {
    $num++
    $cfgKey = $file.Name
    if ($file.DirectoryName -ne $targetDir) { $cfgKey = (Split-Path $file.DirectoryName -Leaf) + '\' + $file.Name }
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ("  [{0}/{1}] {2}" -f $num, $batFiles.Count, $cfgKey) -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    Stop-Zapret
    Start-Sleep -Milliseconds 400
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($file.FullName)`"" -WorkingDirectory $targetDir -PassThru -WindowStyle Minimized
    if (-not (Wait-WinwsReady)) {
      Write-Host "  > winws did not start, skipping." -ForegroundColor Red
      if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
      $attempts += [PSCustomObject]@{ Config=$cfgKey; Started=$false; Ok=0; Err=0; AvgTime=-1; AvgPing=-1; LossAvg=100; UserScore=0; Score=-9999; Detail='no-start' }
      continue
    }

    # --- auto oracle: curl for https targets (2 TLS modes to keep it fast) ---
    $ok = 0; $err = 0; $times = @()
    foreach ($t in ($targetList | Where-Object { $_.Url })) {
      foreach ($tls in @(@("--tlsv1.2","--tls-max","1.2"), @("--tlsv1.3","--tls-max","1.3"))) {
        try {
          $out = & curl.exe -I -s -m 4 --connect-timeout 2 -o NUL -w "%{http_code} %{time_total}" @tls $t.Url 2>&1 | Out-String
          $out = $out.Trim()
          if ($out -match '^(\d{3})\s+([\d\.]+)$') {
            $code = [int]$matches[1]; $tm = [double]$matches[2]
            if ($code -ge 200 -and $code -lt 500) { $ok++; $times += $tm }
            else { $err++ }
          } else { $err++ }
        } catch { $err++ }
      }
    }
    # --- ping oracle ---
    $pings = @()
    foreach ($t in $targetList) {
      try {
        $p = New-Object System.Net.NetworkInformation.Ping
        $rtts = @(); $lost = 0
        for ($i = 0; $i -lt 2; $i++) {
          try {
            $r = $p.Send($t.PingTarget, 1000)
            if ($r.Status -eq 'Success') { $rtts += $r.RoundtripTime } else { $lost++ }
          } catch { $lost++ }
        }
        if ($rtts.Count -gt 0) { $pings += (($rtts | Measure-Object -Average).Average) }
        $p.Dispose()
      } catch { }
    }
    $avgTime = -1; if ($times.Count -gt 0) { $avgTime = [math]::Round(($times | Measure-Object -Average).Average, 2) }
    $avgPing = -1; if ($pings.Count -gt 0) { $avgPing = [math]::Round(($pings | Measure-Object -Average).Average, 0) }

    # --- tcp-connect oracle for captured game ports (TCP only! UDP ports cannot
    # --- be probed by TCP connect: that always FAILs and would poison the score) ---
    $tcpOk = 0; $tcpFail = 0
    foreach ($lp in ($livePorts | Where-Object { $_.Proto -eq 'tcp' } | Select-Object -First 6)) {
      try {
        $cl = New-Object System.Net.Sockets.TcpClient
        $iar = $cl.BeginConnect($lp.Ip, $lp.Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(1500)) { $cl.EndConnect($iar); $tcpOk++ } else { $tcpFail++ }
        $cl.Close()
      } catch { $tcpFail++ }
    }

    $color = "Red"
    if ($ok -gt 0 -or $tcpOk -gt 0) { $color = "Green" }
    Write-Host ("  > auto: HTTP ok={0} err={1} avgT={2}s | tcp ok={3} fail={4} | ping avg={5}ms" -f $ok, $err, $avgTime, $tcpOk, $tcpFail, $avgPing) -ForegroundColor $color
    $udpN = @($livePorts | Where-Object { $_.Proto -ne 'tcp' }).Count
    if ($udpN -gt 0) { Write-Host ("  > note: {0} captured UDP endpoint(s) have no auto-probe (no UDP oracle); your soak score is the oracle for them." -f $udpN) -ForegroundColor DarkGray }

    # --- user oracle (with configurable soak countdown) ---
    $userScore = 0
    if ($askUser) {
      if ($soakSec -gt 0) {
        Write-Host ("  TRY game/site NOW (winws running with this preset). Rating in {0}s..." -f $soakSec) -ForegroundColor Yellow
        for ($w = $soakSec; $w -gt 0; $w--) {
          Write-Host ("    ...{0}s (alt-tab to game, check images/load)" -f $w) -ForegroundColor DarkGray
          Start-Sleep -Seconds 1
        }
      } else {
        Write-Host "  TRY game/site NOW (winws running with this preset)." -ForegroundColor Yellow
      }
      Write-Host "  Rate [1]=bad [2]=ok [3]=great, [S]=stop picking here, Enter=skip:" -ForegroundColor Yellow
      # timed read: wait max 25s for key via Read-Host is blocking; use simple prompt (user controls pace)
      $u = Read-Host "  Your score (1/2/3/S/Enter)"
      if ($u -eq 'S' -or $u -eq 's') {
        $userScore = 0
        $score = ($ok * 10) + ($tcpOk * 5) - ($err * 3) - ($tcpFail * 2)
        if ($avgTime -ge 0) { $score -= ($avgTime * 2) }
        if ($avgPing -ge 0) { $score -= ($avgPing / 100) }
        $attempts += [PSCustomObject]@{ Config=$cfgKey; Started=$true; Ok=$ok; Err=$err; AvgTime=$avgTime; AvgPing=$avgPing; TcpOk=$tcpOk; TcpFail=$tcpFail; LossAvg=-1; UserScore=$userScore; Score=[math]::Round($score,2); Detail='user-stop' }
        Write-Host "[INFO] stopped by user, finishing..." -ForegroundColor Cyan
        Stop-Zapret
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        break
      } elseif ($u -match '^[123]$') { $userScore = [int]$u }
    }

    $score = ($ok * 10) + ($tcpOk * 5) - ($err * 3) - ($tcpFail * 2) + ($userScore * 8)
    if ($avgTime -ge 0) { $score -= ($avgTime * 2) }
    if ($avgPing -ge 0) { $score -= ($avgPing / 100) }
    $score = [math]::Round($score, 2)
    Write-Host ("  > score={0} (user={1})" -f $score, $userScore) -ForegroundColor Cyan

    $attempts += [PSCustomObject]@{
      Config=$cfgKey; Started=$true; Ok=$ok; Err=$err; AvgTime=$avgTime; AvgPing=$avgPing
      TcpOk=$tcpOk; TcpFail=$tcpFail; LossAvg=-1; UserScore=$userScore; Score=$score; Detail=''
    }

    Stop-Zapret
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  }
} finally {
  Stop-Zapret
  Restore-WinwsSnapshot -snapshot $originalWinws
}

if ($attempts.Count -eq 0) { Write-Host "[ERROR] no attempts." -ForegroundColor Red; Pause-End 1 }

$ranked = @($attempts | Sort-Object Score -Descending)
Write-Host ""
Write-Host "=== LIVE RANKING (all attempts kept) ===" -ForegroundColor Cyan
$ranked | Format-Table -AutoSize Config, Score, Ok, Err, TcpOk, AvgTime, AvgPing, UserScore | Out-String | Write-Host

$best = $ranked[0]
$winners = @($ranked | Where-Object { $_.Started -and (($_.Ok -gt 0) -or ($_.TcpOk -gt 0) -or ($_.UserScore -ge 2)) })
Write-Host ""
if ($winners.Count -gt 0) { Write-Host ("[OK] Successful presets: {0}/{1}. Best: {2} (score {3})" -f $winners.Count, $attempts.Count, $best.Config, $best.Score) -ForegroundColor Green }
else { Write-Host ("[WARN] No clear winner. Best attempt: {0} (score {1}). Still saved." -f $best.Config, $best.Score) -ForegroundColor Yellow }

# --- save ---
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$txtFile = Join-Path $resultsDir ("live_results_" + $stamp + ".txt")
$jsonFile = Join-Path $resultsDir ("live_results_" + $stamp + ".json")
$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("LIVE pick $stamp | targets: $($targetList.Count) | tested: $($attempts.Count)")
foreach ($t in $targetList) { if ($t.Url) { [void]$lines.Add(" target: $($t.Name) = $($t.Url)") } else { [void]$lines.Add(" target: $($t.Name) = PING:$($t.PingTarget)") } }
[void]$lines.Add("")
foreach ($a in $ranked) {
  [void]$lines.Add(("{0} | score={1} ok={2} err={3} tcpOk={4} tcpFail={5} avgT={6} avgPing={7} user={8} {9}" -f $a.Config, $a.Score, $a.Ok, $a.Err, $a.TcpOk, $a.TcpFail, $a.AvgTime, $a.AvgPing, $a.UserScore, $a.Detail))
}
$lines | Set-Content -LiteralPath $txtFile -Encoding UTF8
try {
  [PSCustomObject]@{
    date=$stamp; targets=@($targetList); attempts=@($attempts); best=$best.Config
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonFile -Encoding UTF8
} catch { Write-Host "[WARN] json save failed: $_" -ForegroundColor Yellow }
Write-Host ("[OK] Saved: {0}" -f $txtFile) -ForegroundColor Green
Write-Host ("[OK] Saved: {0}" -f $jsonFile) -ForegroundColor Green

# --- point preset builder ---
Write-Host ""
$build = Read-Host "Build POINT preset from BEST ($($best.Config))? (Y/n)"
if ($build -match '^[nN]') { Write-Host "Done without preset. Install winner manually via item 1/2." -ForegroundColor Gray; Pause-End 0 }

# parse winner bat: extract desync lines (reuse simple heuristics from build-custom-preset)
function Find-BatPath($name) {
  $p1 = Join-Path $targetDir $name
  if (Test-Path -LiteralPath $p1) { return $p1 }
  $p2 = Join-Path (Join-Path $targetDir 'Presets') $name
  if (Test-Path -LiteralPath $p2) { return $p2 }
  $leaf = Split-Path $name -Leaf
  $hit = Get-ChildItem -LiteralPath (Join-Path $targetDir 'Presets') -Filter $leaf -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { return $hit.FullName }
  return $null
}
$wPath = Find-BatPath $best.Config
if (-not $wPath) { Write-Host "[ERROR] winner bat not found on disk." -ForegroundColor Red; Pause-End 1 }
$text = Get-Content -LiteralPath $wPath -Raw -Encoding UTF8
$flines = $text -split "`r?`n"
function Pick-Line($preds) {
  foreach ($ln in $flines) {
    $t = $ln.Trim()
    $hit = $true
    foreach ($p in $preds) { if ($t -notmatch $p) { $hit = $false; break } }
    if ($hit) { return $ln }
  }
  return $null
}
function Get-Desync($line) {
  if (-not $line) { return $null }
  $m = [regex]::Match($line, '(--dpi-desync=.*)$')
  if (-not $m.Success) { return $null }
  $d = $m.Groups[1].Value.Trim() -replace '\s*\^?\s*$','' -replace '\s*--new\s*$',''
  return $d.Trim()
}
$tcpDesync = Get-Desync (Pick-Line @('--filter-tcp=80,443 ', 'domains\\general'))
if (-not $tcpDesync) { $tcpDesync = Get-Desync (Pick-Line @('--filter-tcp=', '--dpi-desync=')) }
if (-not $tcpDesync) { $tcpDesync = '--dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig' }
$udpDesync = Get-Desync (Pick-Line @('--filter-udp=443', 'domains\\general'))
if (-not $udpDesync) { $udpDesync = Get-Desync (Pick-Line @('--filter-udp=', '--dpi-desync=')) }
if (-not $udpDesync) { $udpDesync = '--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin"' }

# collect point hosts + ips
$hosts = @()
$ips = @()
foreach ($t in $targetList) {
  if ($t.Url) {
    $h = $t.Url -replace '^https?://','' -replace '/.*$',''
    if ($h -and $h -notmatch '^\d+\.\d+\.\d+\.\d+$') { $hosts += $h }
    else { $ips += $h }
  } else {
    if ($t.PingTarget -match '^\d+\.\d+\.\d+\.\d+$') { $ips += $t.PingTarget }
    else { $hosts += $t.PingTarget }
  }
}
foreach ($lp in $livePorts) { if ($lp.Ip -match '^\d+\.\d+\.\d+\.\d+$') { $ips += $lp.Ip } }
$hosts = @($hosts | Sort-Object -Unique)
$ips = @($ips | Sort-Object -Unique)

# Hit-CIDR matcher: which CIDRs of lists\ipsets\<file> contain captured IPs.
# Used for CloudFront and Telegram: embed ONLY matched CIDRs as a dedicated
# ipset (narrower and more stable than /32s, which rotate inside same CIDRs).
function Find-HitCidrs($ipsetFile, $ips) {
  $hit = @()
  $path = Join-Path $listsDir ("ipsets\" + $ipsetFile)
  if (-not (Test-Path -LiteralPath $path)) { return $hit }
  if (-not $ips -or $ips.Count -eq 0) { return $hit }
  $ranges = @()
  foreach ($ln in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
    $t = $ln.Trim()
    if ($t -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)/(\d+)$') {
      $bits = [int]$matches[5]
      if ($bits -ge 0 -and $bits -le 32) {
        $ip = [uint64]$matches[1]*16777216 + [uint64]$matches[2]*65536 + [uint64]$matches[3]*256 + [uint64]$matches[4]
        $size = [math]::Pow(2, (32 - $bits))
        $st = [math]::Floor($ip / $size) * $size
        $ranges += [PSCustomObject]@{ Cidr=$t; Start=[uint64]$st; End=[uint64]($st + $size - 1) }
      }
    }
  }
  foreach ($ip in $ips) {
    try {
      $b = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes()
      if ($b.Length -ne 4) { continue }
      $n = ([uint64]$b[0]*16777216)+([uint64]$b[1]*65536)+([uint64]$b[2]*256)+[uint64]$b[3]
      foreach ($r in $ranges) {
        if ($n -ge $r.Start -and $n -le $r.End) { $hit += $r.Cidr; break }
      }
    } catch { }
  }
  return @($hit | Sort-Object -Unique)
}
# CloudFront: match captured IPs against official CF CIDRs (cloudfront.txt from
# update-aws.ps1).
$cfHitCidrs = @(Find-HitCidrs "cloudfront.txt" $ips)
if ($cfHitCidrs.Count -gt 0) {
  Write-Host ("[INFO] Captured IPs fall into {0} CloudFront CIDR(s): {1}" -f $cfHitCidrs.Count, ($cfHitCidrs -join ', ')) -ForegroundColor Cyan
}
# Telegram: same over telegram.txt (DC IPs rotate; ranges are stable).
$tgHitCidrs = @(Find-HitCidrs "telegram.txt" $ips)
if ($tgHitCidrs.Count -gt 0) {
  Write-Host ("[INFO] Captured IPs fall into {0} Telegram CIDR(s): {1}" -f $tgHitCidrs.Count, ($tgHitCidrs -join ', ')) -ForegroundColor Cyan
}

# tcp ports seen (default 443 + captured)
$tcpPorts = @($livePorts | Where-Object { $_.Proto -eq 'tcp' } | ForEach-Object { $_.Port })
$tcpPorts += @(443)
$tcpPorts = @($tcpPorts | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
$tcpPortStr = ($tcpPorts -join ',')
if (-not $tcpPortStr) { $tcpPortStr = '443' }

$safeName = ($best.Config -replace '[\\\/:*?"<>|]', '_')
if ($safeName.Length -gt 40) { $safeName = $safeName.Substring(0, 40) }
$pointName = "point-$safeName"
$customDir = Join-Path $targetDir 'Presets\Custom'
if (-not (Test-Path -LiteralPath $customDir)) { New-Item -ItemType Directory -Path $customDir | Out-Null }
$ipFile = Join-Path $listsDir ("ipsets\point-" + $stamp + ".txt")
# NOTE: ipset files are read by winws: must be UTF-8 WITHOUT BOM (.NET, PS 5.1 has no utf8NoBOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
if ($ips.Count -gt 0) {
  [IO.File]::WriteAllLines($ipFile, @($ips | ForEach-Object { "$_/32" } | Sort-Object -Unique), $utf8NoBom)
} else {
  [IO.File]::WriteAllText($ipFile, "203.0.113.113/32", $utf8NoBom)
}
$ipRel = "ipsets\" + (Split-Path $ipFile -Leaf)
$cfRel = $null
if ($cfHitCidrs.Count -gt 0) {
  $cfFile = Join-Path $listsDir ("ipsets\point-cf-" + $stamp + ".txt")
  [IO.File]::WriteAllLines($cfFile, @($cfHitCidrs), $utf8NoBom)
  $cfRel = "ipsets\" + (Split-Path $cfFile -Leaf)
}
$tgRel = $null
if ($tgHitCidrs.Count -gt 0) {
  $tgFile = Join-Path $listsDir ("ipsets\point-tg-" + $stamp + ".txt")
  [IO.File]::WriteAllLines($tgFile, @($tgHitCidrs), $utf8NoBom)
  $tgRel = "ipsets\" + (Split-Path $tgFile -Leaf)
}
$excl = '--hostlist-exclude="%LISTS%domains\exclude.txt" --hostlist-exclude="%LISTS%domains\exclude-user.txt" --ipset-exclude="%LISTS%ipsets\exclude.txt" --ipset-exclude="%LISTS%ipsets\exclude-user.txt"'
$filterLines = @()
# CF block FIRST: winws applies first matching --filter, so game CF traffic
# gets the winner desync before generic rules.
if ($cfRel) {
  $filterLines += ('--filter-tcp=80,443,8443 --ipset="%LISTS%' + $cfRel + '" ' + $excl + ' ' + $tcpDesync)
  $filterLines += ('--filter-udp=443 --ipset="%LISTS%' + $cfRel + '" ' + $excl + ' ' + $udpDesync)
}
# Telegram block next (same priority reason: DC IPs rotate, ranges don't).
if ($tgRel) {
  $filterLines += ('--filter-tcp=80,443 --ipset="%LISTS%' + $tgRel + '" ' + $excl + ' ' + $tcpDesync)
  $filterLines += ('--filter-udp=443 --ipset="%LISTS%' + $tgRel + '" ' + $excl + ' ' + $udpDesync)
}
foreach ($h in $hosts) { $filterLines += ('--filter-tcp=' + $tcpPortStr + ' --hostlist-domains=' + $h + ' ' + $excl + ' ' + $tcpDesync) }
if ($ips.Count -gt 0) {
  $filterLines += ('--filter-tcp=' + $tcpPortStr + ' --ipset="%LISTS%' + $ipRel + '" ' + $excl + ' ' + $tcpDesync)
  $filterLines += ('--filter-udp=443 --ipset="%LISTS%' + $ipRel + '" ' + $excl + ' ' + $udpDesync)
}
if ($filterLines.Count -eq 0) { Write-Host "[ERROR] nothing to put into point preset." -ForegroundColor Red; Pause-End 1 }

$wfTcp = $tcpPortStr
$wfUdp = '443'
if ($cfRel -or $tgRel) {
  # CF/TG blocks need 80,443,8443 diverted even if capture did not see port 80
  $wfTcp = ((@($tcpPorts) + @(80, 8443) | Where-Object { $_ -gt 0 } | Sort-Object -Unique) -join ',')
}
$title = "point LIVE $stamp from $($best.Config)"
$head = "@echo off`r`nchcp 65001 > nul`r`n:: POINT preset built from live_results_$stamp.json | winner=$($best.Config)`r`n`r`ncd /d `"%~dp0`"`r`n"
$head += 'for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"' + "`r`n"
$head += 'call "%ROOT%service.bat" status_zapret' + "`r`n" + 'call "%ROOT%service.bat" check_updates' + "`r`necho:`r`n"
$head += "set `"BIN=%ROOT%bin\`"`r`nset `"LISTS=%ROOT%lists\`"`r`ncd /d %BIN%`r`n`r`n"
$head += 'start "zapret: ' + $title + '" /min "%BIN%winws.exe" --wf-tcp=' + $wfTcp + ' --wf-udp=' + $wfUdp + " ^`r`n"
$body = ""
for ($i = 0; $i -lt $filterLines.Count; $i++) {
  $suffix = " --new ^`r`n"
  if ($i -eq $filterLines.Count - 1) { $suffix = "`r`n" }
  $body += ($filterLines[$i] + $suffix)
}
$outBat = Join-Path $customDir ("preset-point (AUTO " + $stamp + ").bat")
[IO.File]::WriteAllText($outBat, ($head + $body), $utf8NoBom)
Write-Host ""
Write-Host ("[OK] POINT preset: {0}" -f $outBat) -ForegroundColor Green
Write-Host ("[OK] POINT ipset: {0} ({1} ips)" -f $ipFile, $ips.Count) -ForegroundColor Green
if ($cfRel) { Write-Host ("[OK] POINT CloudFront ipset: {0} ({1} CIDRs)" -f (Join-Path $listsDir $cfRel), $cfHitCidrs.Count) -ForegroundColor Green }
if ($tgRel) { Write-Host ("[OK] POINT Telegram ipset: {0} ({1} CIDRs)" -f (Join-Path $listsDir $tgRel), $tgHitCidrs.Count) -ForegroundColor Green }
Write-Host "Next: manager item 1 (run) to test it, item 2 (service) to install." -ForegroundColor Cyan
Write-Host "NOTE: point preset is NARROW (only live hosts). Keep your main preset for browser; install point only if game is the priority, or merge blocks manually." -ForegroundColor Yellow
Pause-End 0
