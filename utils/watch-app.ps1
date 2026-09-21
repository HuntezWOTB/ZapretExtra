# watch-app.ps1 v2 (ZapretExtra 1.01 LIVE) - tracker process/domain -> live targets
# ASCII-only, PS 5.1 safe.
# Output:
#   utils\live-targets.txt   (targets.txt format: Name = "https://..." / "PING:x.x.x.x")
#   utils\live-capture.json  (raw capture: process, ip, port, proto, hits, host, probe + per-host summary)
# Usage:
#   powershell -ExecutionPolicy Bypass -File utils\watch-app.ps1 [-Exe notepad] [-Domain example.com] [-Duration 15]

param(
  [string]$Exe = "",
  [string]$Domain = "",
  [int]$Duration = 45
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$utilsDir = $PSScriptRoot
$listsDir = Join-Path $rootDir "lists"
$outTargets = Join-Path $utilsDir "live-targets.txt"
$outJson = Join-Path $utilsDir "live-capture.json"

function Pause-End($code) {
  Write-Host ""
  try { Read-Host "Press Enter to exit" | Out-Null } catch { }
  exit $code
}

function Wait-AnyKey($msg) {
  Write-Host $msg -ForegroundColor Yellow
  try {
    while ([System.Console]::KeyAvailable) { [void][System.Console]::ReadKey($true) }
    [void][System.Console]::ReadKey($true)
  } catch { [void](Read-Host) }
}

# --- admin check (need it for full TCP table) ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "[ERROR] Run as Administrator (need TCP table + winws interop)." -ForegroundColor Red
  Pause-End 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Watch-App: capture live endpoints of game/site (v1.01)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Duration is configurable: quick check (15s, e.g. "did images load?") or long (60-120s).
function Read-Duration($current) {
  $d = Read-Host ("Capture duration sec (10-300, default {0}; 15 = quick check)" -f $current)
  if ($d -match '^\d+$' -and [int]$d -ge 10 -and [int]$d -le 300) { return [int]$d }
  return $current
}

# --- interactive mode if no args ---
if (-not $Exe -and -not $Domain) {
  Write-Host ""
  Write-Host "  [1] Track .exe by name (game/app, e.g. TestGame.exe)" -ForegroundColor Gray
  Write-Host "  [2] Track domain/IP manually (site/server, e.g. example.com)" -ForegroundColor Gray
  $c = Read-Host "Select 1 or 2"
  if ($c -eq '2') {
    $Domain = Read-Host "Enter domain or IP"
    $Duration = Read-Duration $Duration
  } else {
    $Exe = Read-Host "Enter exe name (with or without .exe)"
    $Duration = Read-Duration $Duration
  }
} elseif (-not ($PSBoundParameters.ContainsKey('Duration'))) {
  # script called with -Exe/-Domain but no explicit -Duration: still allow override
  Write-Host ("[INFO] Capture duration: {0}s (pass -Duration N or press Enter to keep)" -f $Duration) -ForegroundColor Gray
  $Duration = Read-Duration $Duration
}

$Exe = $Exe.Trim().Trim('"')
$Domain = $Domain.Trim()
if ($Exe -and -not $Exe.EndsWith('.exe')) { $Exe = $Exe + '.exe' }

$stats = @{}   # key "proto|ip|port" -> @{Proto,Ip,Port,Hits,States}
$procNames = @()

if ($Domain) {
  Write-Host "[INFO] Manual mode: $Domain" -ForegroundColor Cyan
  # resolve domain to IPs for ping targets
  $ips = @()
  try {
    $recs = [System.Net.Dns]::GetHostAddresses($Domain) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 4
    foreach ($r in $recs) { $ips += $r.IPAddressToString }
  } catch {
    Write-Host "[WARN] DNS resolve failed for $Domain : $_" -ForegroundColor Yellow
  }
  if ($Domain -match '^\d+\.\d+\.\d+\.\d+$') { $ips = @($Domain) }
  $stats["tcp|$Domain|443"] = @{ Proto='tcp'; Ip=$Domain; Port=443; Hits=1; States=@('manual'); Host=$Domain; IsDomain=$true }
  foreach ($ip in $ips) {
    $stats["ping|$ip|0"] = @{ Proto='ping'; Ip=$ip; Port=0; Hits=1; States=@('manual-resolve'); Host=$Domain; IsDomain=$false }
  }
  $procNames = @("manual:$Domain")
} else {
  # --- exe mode: find PIDs ---
  $procs = @(Get-Process -Name ($Exe -replace '\.exe$','') -ErrorAction SilentlyContinue)
  if (-not $procs -or $procs.Count -eq 0) {
    Write-Host "[ERROR] Process $Exe not running. Start the game/app first, then rerun." -ForegroundColor Red
    Write-Host "Hint: launch it via manager item 10 (Apps) or normally." -ForegroundColor Gray
    Pause-End 1
  }
  $pids = @($procs | ForEach-Object { $_.Id })
  $procNames = @($procs | ForEach-Object { "$($_.ProcessName) (pid $($_.Id))" })
  Write-Host ("[INFO] Tracking: {0}" -f ($procNames -join ', ')) -ForegroundColor Green
  Write-Host "[INFO] Play/use the app NOW: open problem screen, retry failed action." -ForegroundColor Yellow
  Write-Host ("[INFO] Capturing {0}s (poll every 2s)..." -f $Duration) -ForegroundColor Cyan

  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $Duration) {
    $elapsed = [int]((Get-Date) - $t0).TotalSeconds
    Write-Progress -Activity "Capturing traffic of $Exe" -Status "$elapsed / $Duration s, endpoints: $($stats.Count)" -PercentComplete ([int]($elapsed * 100 / $Duration))
    # refresh PID list (game may respawn)
    try { $pids = @(Get-Process -Name ($Exe -replace '\.exe$','') -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }) } catch { }
    try {
      $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $pids -contains $_.OwningProcess }
      foreach ($c in $conns) {
        $rip = $c.RemoteAddress; $rport = $c.RemotePort
        if (-not $rip -or $rip -eq '0.0.0.0' -or $rip -eq '::' -or $rip.StartsWith('127.') -or $rip -eq '::1') { continue }
        if ($rip.StartsWith('224.') -or $rip.StartsWith('239.') -or $rip -eq '255.255.255.255') { continue }
        $k = "tcp|$rip|$rport"
        if (-not $stats.ContainsKey($k)) { $stats[$k] = @{ Proto='tcp'; Ip=$rip; Port=$rport; Hits=0; States=@() } }
        $stats[$k].Hits++
        if ($stats[$k].States -notcontains $c.State) { $stats[$k].States += @($c.State) }
      }
    } catch { }
    try {
      $u = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Where-Object { $pids -contains $_.OwningProcess }
      foreach ($e in $u) {
        $rip = $e.RemoteAddress; $rport = $e.RemotePort
        if (-not $rip -or $rip -eq '0.0.0.0' -or $rip -eq '::' -or $rip -eq '*' -or $rport -eq 0) { continue }
        if ($rip.StartsWith('127.') -or $rip -eq '::1') { continue }
        $k = "udp|$rip|$rport"
        if (-not $stats.ContainsKey($k)) { $stats[$k] = @{ Proto='udp'; Ip=$rip; Port=$rport; Hits=0; States=@('udp') } }
        $stats[$k].Hits++
      }
    } catch { }
    Start-Sleep -Seconds 2
  }
  Write-Progress -Activity "done" -Completed
}

if ($stats.Count -eq 0) {
  Write-Host "[ERROR] No endpoints captured. App may use system service for net (launcher) or no traffic yet." -ForegroundColor Red
  Write-Host "Hint: increase duration, reproduce the FAIL action during capture." -ForegroundColor Gray
  Pause-End 1
}

# --- rank by hits, take top, resolve hosts, quick probe ---
Write-Host ""
Write-Host ("[INFO] Raw endpoints: {0}" -f $stats.Count) -ForegroundColor Cyan
$ranked = @($stats.GetEnumerator() | Sort-Object { $_.Value.Hits } -Descending)

# quick probe: ping (1 echo, 800ms) + TCP connect 2s for tcp ports
function Test-Fast($ip, $port, $proto) {
  $pingOk = $false; $pingMs = -1
  try {
    $p = New-Object System.Net.NetworkInformation.Ping
    $r = $p.Send($ip, 800)
    if ($r.Status -eq 'Success') { $pingOk = $true; $pingMs = $r.RoundtripTime }
    $p.Dispose()
  } catch { }
  $tcpOk = $null; $tcpMs = -1
  if ($proto -eq 'tcp' -and $port -gt 0) {
    try {
      $sw = [Diagnostics.Stopwatch]::StartNew()
      $cl = New-Object System.Net.Sockets.TcpClient
      $iar = $cl.BeginConnect($ip, $port, $null, $null)
      if ($iar.AsyncWaitHandle.WaitOne(2000)) { $cl.EndConnect($iar); $tcpOk = $true } else { $tcpOk = $false }
      $sw.Stop(); $tcpMs = [int]$sw.ElapsedMilliseconds
      $cl.Close()
    } catch { $tcpOk = $false }
  }
  return @{ PingOk=$pingOk; PingMs=$pingMs; TcpOk=$tcpOk; TcpMs=$tcpMs }
}

$rows = @()
$n = 0
$maxProbe = 15   # probe only top-15 to keep it fast

# --- net annotation: CloudFront / AWS membership via local ipset files ---
# cloudfront.txt is maintained by update-aws.ps1 (official CloudFront + AWS fallback).
function Convert-IpUint64($ip) {
  try {
    $b = ([System.Net.IPAddress]::Parse($ip)).GetAddressBytes()
    if ($b.Length -ne 4) { return $null }
    return ([uint64]$b[0] * 16777216) + ([uint64]$b[1] * 65536) + ([uint64]$b[2] * 256) + [uint64]$b[3]
  } catch { return $null }
}
function Import-CidrRanges($path) {
  $out = @()
  if (-not (Test-Path -LiteralPath $path)) { return $out }
  foreach ($ln in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
    $t = $ln.Trim()
    if ($t -match '^(\d+)\.(\d+)\.(\d+)\.(\d+)(/(\d+))?$') {
      $o1=[uint64]$matches[1]; $o2=[uint64]$matches[2]; $o3=[uint64]$matches[3]; $o4=[uint64]$matches[4]
      if ($o1 -gt 255 -or $o2 -gt 255 -or $o3 -gt 255 -or $o4 -gt 255) { continue }
      $bits = 32
      if ($matches[6] -ne $null -and $matches[6] -ne '') { $bits = [int]$matches[6] }
      if ($bits -lt 0 -or $bits -gt 32) { continue }
      $ip = $o1*16777216 + $o2*65536 + $o3*256 + $o4
      $size = [math]::Pow(2, (32 - $bits))
      $start = [math]::Floor($ip / $size) * $size
      $out += [PSCustomObject]@{ Start=[uint64]$start; End=[uint64]($start + $size - 1) }
    }
  }
  return @($out | Sort-Object Start)
}
function Test-InRanges($ranges, $ipNum) {
  $lo = 0; $hi = $ranges.Count - 1; $ans = -1
  while ($lo -le $hi) {
    $mid = [int](($lo + $hi) / 2)
    if ($ranges[$mid].Start -le $ipNum) { $ans = $mid; $lo = $mid + 1 } else { $hi = $mid - 1 }
  }
  if ($ans -ge 0 -and $ipNum -le $ranges[$ans].End) { return $true }
  return $false
}
$cfRanges = Import-CidrRanges (Join-Path $listsDir "ipsets\cloudfront.txt")
$awsRanges = Import-CidrRanges (Join-Path $listsDir "ipsets\amazon.txt")
$tgRanges = Import-CidrRanges (Join-Path $listsDir "ipsets\telegram.txt")
$fbRanges = Import-CidrRanges (Join-Path $listsDir "ipsets\facebook.txt")
$twRanges = Import-CidrRanges (Join-Path $listsDir "ipsets\twitter.txt")
if ($cfRanges.Count -eq 0 -and $awsRanges.Count -eq 0) {
  Write-Host "[INFO] No cloudfront/amazon ipset files: net tags off. Run update-aws.ps1 (manager item 5)." -ForegroundColor DarkGray
} else {
  Write-Host ("[INFO] Net ranges loaded: CloudFront={0} AWS={1} Telegram={2} Facebook={3} Twitter={4}." -f $cfRanges.Count, $awsRanges.Count, $tgRanges.Count, $fbRanges.Count, $twRanges.Count) -ForegroundColor DarkGray
}
# lists\ipsets\<svc>.txt snapshots as "known service IP" oracle (exact hits).
# Bare names, one file per service (discord, google, instagram, general —
# services without a range file). Maintained by build-service-ipsets.ps1.
# (No preset references them by default: volatile snapshots, diagnostic use
# plus the 'known:<svc>' tag below and --ipset for manual pinpoint presets.)
$resolvedRanges = @{}
foreach ($svc in @('discord','google','instagram','general')) {
  $rr = Import-CidrRanges (Join-Path $listsDir ("ipsets\" + $svc + ".txt"))
  if ($rr.Count -gt 0) { $resolvedRanges[$svc] = $rr }
}
if ($resolvedRanges.Count -gt 0) {
  Write-Host ("[INFO] Resolved snapshots loaded: {0}." -f ($resolvedRanges.Keys -join ', ')) -ForegroundColor DarkGray
} else {
  Write-Host "[INFO] No ipset snapshots: 'known' tags off. Run build-service-ipsets.ps1." -ForegroundColor DarkGray
}
foreach ($en in $ranked) {
  $n++
  $v = $en.Value
  $host_ = $null
  if ($v.ContainsKey('Host') -and $v.Host) { $host_ = $v.Host }
  else {
    if ($v.Ip -match '^\d+\.\d+\.\d+\.\d+$') {
      try { $host_ = ([System.Net.Dns]::GetHostEntry($v.Ip)).HostName } catch { $host_ = $null }
    } else { $host_ = $v.Ip }
  }
  $probe = @{ PingOk=$null; PingMs=-1; TcpOk=$null; TcpMs=-1 }
  if ($n -le $maxProbe) { $probe = Test-Fast $v.Ip $v.Port $v.Proto }
  $suspect = $false
  if ($probe.TcpOk -eq $false) { $suspect = $true }
  elseif ($probe.PingOk -eq $false -and $v.Proto -eq 'ping') { $suspect = $true }
  # net tag: exact CIDR match wins, hostname keywords give a weak (?) hint
  $net = "-"
  if ($v.Ip -match '^\d+\.\d+\.\d+\.\d+$') {
    $num = Convert-IpUint64 $v.Ip
    if ($num -ne $null) {
      if ($cfRanges.Count -gt 0 -and (Test-InRanges $cfRanges $num)) { $net = "CloudFront" }
      elseif ($awsRanges.Count -gt 0 -and (Test-InRanges $awsRanges $num)) { $net = "AWS" }
      elseif ($tgRanges.Count -gt 0 -and (Test-InRanges $tgRanges $num)) { $net = "Telegram" }
      elseif ($fbRanges.Count -gt 0 -and (Test-InRanges $fbRanges $num)) { $net = "Facebook" }
      elseif ($twRanges.Count -gt 0 -and (Test-InRanges $twRanges $num)) { $net = "Twitter" }
    }
    if ($net -eq "-" -and $num -ne $null) {
      foreach ($svc in @($resolvedRanges.Keys | Sort-Object)) {
        if (Test-InRanges $resolvedRanges[$svc] $num) { $net = "known:$svc"; break }
      }
    }
    if ($net -eq "-" -and $host_ -match 'cloudfront') { $net = "CloudFront?" }
    elseif ($net -eq "-" -and $host_ -match 'amazonaws|compute\.amazon|awsglobalaccelerator') { $net = "AWS?" }
  } else {
    if ($v.Ip -match 'cloudfront') { $net = "CloudFront?" }
    elseif ($v.Ip -match 'amazonaws|compute\.amazon') { $net = "AWS?" }
  }
  $rows += [PSCustomObject]@{
    Proto=$v.Proto; Ip=$v.Ip; Port=$v.Port; Hits=$v.Hits
    States=($v.States -join ','); Host=$host_; Net=$net
    PingOk=$probe.PingOk; PingMs=$probe.PingMs
    TcpOk=$probe.TcpOk; TcpMs=$probe.TcpMs; Suspect=$suspect
  }
}

Write-Host ""
Write-Host "=== CAPTURED endpoints (top 20 by hits) ===" -ForegroundColor Cyan
$rows | Select-Object -First 20 | Format-Table -AutoSize Proto, Ip, Port, Hits, Net, PingOk, TcpOk, Host | Out-String | Write-Host

# --- per-host HTTP check (does content actually load? code + time) ---
# Only for DNS names (not bare IPs), top-8 hosts by hits, TLS1.2 HEAD.
function Test-HttpHost($hostName) {
  try {
    $out = & curl.exe -I -s -m 5 --connect-timeout 3 --tlsv1.2 --tls-max 1.2 -o NUL -w "%{http_code} %{time_total}" ("https://" + $hostName) 2>&1 | Out-String
    $out = $out.Trim()
    if ($out -match '^(\d{3})\s+([\d\.]+)$') {
      return @{ Code=[int]$matches[1]; Time=[double]$matches[2]; Error=$null }
    }
    return @{ Code=-1; Time=-1; Error=$out }
  } catch { return @{ Code=-1; Time=-1; Error=[string]$_ } }
}

$hostGroups = @{}  # host -> @(rows)
foreach ($r in $rows) {
  $hk = $r.Host
  if (-not $hk) { $hk = $r.Ip }
  if (-not $hostGroups.ContainsKey($hk)) { $hostGroups[$hk] = @() }
  $hostGroups[$hk] += $r
}
$hostOrder = @($hostGroups.GetEnumerator() | Sort-Object { ($_.Value | Measure-Object -Property Hits -Sum).Sum } -Descending)

$httpCache = @{}
$httpCheckN = 0
foreach ($en in $hostOrder) {
  $hk = $en.Key
  if ($httpCheckN -ge 8) { break }
  # skip bare IPs (curl https://IP gives cert mismatch, meaningless here)
  if ($hk -match '^\d+\.\d+\.\d+\.\d+$') { continue }
  if ($hk -match '_') { continue }  # sanitized fallback, not a real host
  $httpCheckN++
  Write-Host ("[INFO] HTTP check {0}/{1}: {2} ..." -f $httpCheckN, [Math]::Min(8, ($hostOrder | Where-Object { $_.Key -notmatch '^\d+\.\d+\.\d+\.\d+$' } | Measure-Object).Count), $hk) -ForegroundColor DarkGray
  $httpCache[$hk] = Test-HttpHost $hk
}

# --- detailed per-domain report ---
$hostSummary = @()
# CNAME chains reveal which CDN/cloud a domain REALLY sits on
# (e.g. game-patch.example.com -> d1234abcd.cloudfront.net).
# No public "all CloudFront domains" list exists (customer CNAMEs and random
# <id>.cloudfront.net distribution IDs are not enumerable), so we resolve
# the chain live for YOUR captured traffic (top-12 hosts by hits).
$cnameCache = @{}
$cn = 0
function Get-CnameChain($h) {
  if ($cnameCache.ContainsKey($h)) { return $cnameCache[$h] }
  $chain = @()
  try {
    $cur = $h
    for ($i = 0; $i -lt 3; $i++) {
      $r = Resolve-DnsName -Name $cur -Type CNAME -ErrorAction Stop | Where-Object { $_.NameHost }
      if (-not $r) { break }
      $nh = ($r | Select-Object -First 1).NameHost.TrimEnd('.')
      $chain += $nh
      if ($nh -eq $cur) { break }
      $cur = $nh
    }
  } catch { }
  $cnameCache[$h] = $chain
  return $chain
}
Write-Host ""
Write-Host "=== PER-DOMAIN DETAIL ===" -ForegroundColor Cyan
foreach ($en in $hostOrder) {
  $hk = $en.Key
  $eps = @($en.Value)
  $totalHits = ($eps | Measure-Object -Property Hits -Sum).Sum
  $ips = @($eps | ForEach-Object { $_.Ip } | Sort-Object -Unique)
  $ports = @($eps | ForEach-Object { "{0}/{1}" -f $_.Proto, $_.Port } | Sort-Object -Unique)
  $states = @($eps | ForEach-Object { $_.States } | Where-Object { $_ } | Sort-Object -Unique)
  $nets = @($eps | ForEach-Object { $_.Net } | Where-Object { $_ -and $_ -ne '-' } | Sort-Object -Unique)
  # CNAME chain (top-12 hosts only: bounds DNS time on dead names)
  $cname = @()
  if ($cn -lt 12 -and $hk -notmatch '^\d+\.\d+\.\d+\.\d+$' -and $hk -notmatch '_') {
    $cn++
    $cname = @(Get-CnameChain $hk)
    if ($cname.Count -gt 0) {
      $joined = ($cname -join ' ')
      if ($nets.Count -eq 0) {
        if ($joined -match 'cloudfront') { $nets += @('CloudFront?') }
        elseif ($joined -match 'amazonaws|compute\.amazon|awsglobalaccelerator') { $nets += @('AWS?') }
      }
    }
  }

  # probe rollup
  $pingTxt = @($eps | Where-Object { $_.PingMs -ge 0 } | ForEach-Object { $_.PingMs })
  $pingAvg = -1; if ($pingTxt.Count -gt 0) { $pingAvg = [int](($pingTxt | Measure-Object -Average).Average) }
  $tcpFails = @($eps | Where-Object { $_.TcpOk -eq $false }).Count
  $tcpOks = @($eps | Where-Object { $_.TcpOk -eq $true }).Count

  $http = $null
  if ($httpCache.ContainsKey($hk)) { $http = $httpCache[$hk] }

  # verdict + reason
  $reasons = @()
  if ($tcpFails -gt 0) { $reasons += ("tcp-connect FAIL x{0}" -f $tcpFails) }
  if ($http -and $http.Code -eq -1) { $reasons += "http no-answer/timeout" }
  elseif ($http -and ($http.Code -lt 200 -or $http.Code -ge 500)) { $reasons += ("http code={0}" -f $http.Code) }
  $verdict = "OK"; $vColor = "Green"
  if ($reasons.Count -gt 0) { $verdict = "SUSPECT (" + ($reasons -join '; ') + ")"; $vColor = "Yellow" }

  Write-Host ""
  Write-Host ("  [{0}]" -f $hk) -ForegroundColor White
  Write-Host ("    hits={0} endpoints={1} ips={2}" -f $totalHits, $eps.Count, ($ips -join ', ')) -ForegroundColor Gray
  Write-Host ("    ports: {0} | states: {1}" -f ($ports -join ', '), ($states -join ', ')) -ForegroundColor Gray
  if ($nets.Count -gt 0) { Write-Host ("    net: {0}" -f ($nets -join ', ')) -ForegroundColor Cyan }
  else { Write-Host "    net: unknown (not in cloudfront/amazon/known lists)" -ForegroundColor DarkGray }
  if ($cname.Count -gt 0) { Write-Host ("    cname: {0} -> {1}" -f $hk, ($cname -join ' -> ')) -ForegroundColor Gray }
  foreach ($e in ($eps | Sort-Object Hits -Descending | Select-Object -First 5)) {
    $pm = "n/a"; if ($e.PingMs -ge 0) { $pm = "{0}ms" -f $e.PingMs }
    $tm = "n/a"; if ($e.TcpMs -ge 0) { $tm = "{0}ms" -f $e.TcpMs }
    Write-Host ("    {0} {1}:{2} hits={3} ping={4} tcp={5}" -f $e.Proto, $e.Ip, $e.Port, $e.Hits, $pm, $tm) -ForegroundColor DarkGray
  }
  if ($http) {
    if ($http.Code -ne -1) { Write-Host ("    http: code={0} time={1}s (TLS1.2 HEAD https://{2})" -f $http.Code, $http.Time, $hk) -ForegroundColor Gray }
    else { Write-Host ("    http: NO ANSWER (timeout/block?). Content likely NOT loading." -f $null) -ForegroundColor Yellow }
  } else {
    Write-Host "    http: skipped (bare IP or over check limit)" -ForegroundColor DarkGray
  }
  if ($pingAvg -ge 0) { Write-Host ("    ping avg: {0}ms" -f $pingAvg) -ForegroundColor Gray }
  Write-Host ("    verdict: {0}" -f $verdict) -ForegroundColor $vColor

  $hostSummary += [PSCustomObject]@{
    Host=$hk; TotalHits=$totalHits; Endpoints=$eps.Count
    Ips=@($ips); Ports=@($ports); States=@($states); Nets=@($nets); Cname=@($cname)
    PingAvgMs=$pingAvg; TcpOk=$tcpOks; TcpFail=$tcpFails
    HttpCode=$(if ($http) { $http.Code } else { $null })
    HttpTime=$(if ($http) { $http.Time } else { $null })
    Verdict=$verdict
  }
}

# --- build live-targets.txt: prefer SUSPECT + top by hits, max 6 ---
$suspects = @($rows | Where-Object { $_.Suspect -eq $true })
$top = @($rows | Sort-Object { if ($_.Suspect) { 0 } else { 1 } }, Hits -Descending | Select-Object -First 6)
if ($top.Count -eq 0) { $top = @($rows | Select-Object -First 6) }

$lines = @()
$lines += '# live-targets.txt - AUTO from watch-app.ps1 | ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$lines += '# Format same as targets.txt: Name = "https://host" or "PING:ip"'
$lines += ''
$i = 0
foreach ($r in $top) {
  $i++
  $safeHost = $r.Host
  if (-not $safeHost) { $safeHost = $r.Ip }
  $safeHost = ($safeHost -replace '[^A-Za-z0-9\.\-]', '_')
  if ($r.Proto -eq 'ping' -or ($r.Port -eq 0)) {
    $lines += ('LivePing{0} = "PING:{1}"' -f $i, $r.Ip)
  } elseif ($r.Ip -match '^\d+\.\d+\.\d+\.\d+$' -and (-not $r.Host -or ($r.Host -match '^\d+\.\d+\.\d+\.\d+$'))) {
    # bare IP without hostname: TCP probe via curl needs https://IP -> cert mismatch;
    # still usable as ping + tcp-connect oracle in live-pick
    $lines += ('LiveIp{0} = "PING:{1}"' -f $i, $r.Ip)
  } else {
    $h = $r.Host
    if (-not $h -or ($h -match '^\d+\.\d+\.\d+\.\d+$')) { $h = $r.Ip }
    $lines += ('LiveTarget{0} = "https://{1}"' -f $i, $h)
  }
}
# dedupe keep order
$seen = @{}
$final = @()
foreach ($ln in $lines) {
  if ($ln.StartsWith('#') -or $ln.Trim() -eq '') { $final += $ln; continue }
  if (-not $seen.ContainsKey($ln)) { $seen[$ln] = 1; $final += $ln }
}
$final | Set-Content -LiteralPath $outTargets -Encoding UTF8

# json dump
try {
  $dump = [PSCustomObject]@{
    date=(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'); exe=$Exe; domain=$Domain
    procs=$procNames; duration=$Duration
    endpoints=@($rows | ForEach-Object {
      [PSCustomObject]@{ proto=$_.Proto; ip=$_.Ip; port=$_.Port; hits=$_.Hits; states=$_.States; host=$_.Host; net=$_.Net; pingOk=$_.PingOk; pingMs=$_.PingMs; tcpOk=$_.TcpOk; tcpMs=$_.TcpMs; suspect=$_.Suspect }
    })
    hosts=@($hostSummary | ForEach-Object {
      [PSCustomObject]@{ host=$_.Host; totalHits=$_.TotalHits; endpoints=$_.Endpoints; ips=@($_.Ips); ports=@($_.Ports); states=@($_.States); nets=@($_.Nets); cname=@($_.Cname); pingAvgMs=$_.PingAvgMs; tcpOk=$_.TcpOk; tcpFail=$_.TcpFail; httpCode=$_.HttpCode; httpTime=$_.HttpTime; verdict=$_.Verdict }
    })
  }
  $dump | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outJson -Encoding UTF8
} catch { Write-Host "[WARN] json dump failed: $_" -ForegroundColor Yellow }

Write-Host ""
Write-Host ("[OK] Targets: {0} -> {1}" -f $outTargets, ($final | Where-Object { $_ -match '=' } | Measure-Object).Count) -ForegroundColor Green
Write-Host ("[OK] Raw dump: {0}" -f $outJson) -ForegroundColor Green
Write-Host "Next: manager item 11 -> step 2 (live-pick) will test presets against these." -ForegroundColor Cyan
Pause-End 0
