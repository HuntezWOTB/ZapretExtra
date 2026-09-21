# build-service-ipsets.ps1 — resolves every host in lists\domains\<svc>.txt
# into lists\ipsets\<svc>.txt (v4 as /32, v6 as /128, sorted unique).
# Bare names, one file per service: different resources stay separate, so a
# pinpoint preset can reference exactly one service file (--ipset) instead
# of dragging the big range lists in. Small selective ipsets = less divert.
# Only services WITHOUT a range file get a snapshot (amazon/cloudflare are
# covered by their ranges; their snapshots were dropped as redundant).
# Re-run to refresh. Skips ^negations. ASCII-only.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$listsDir = Join-Path (Split-Path $PSScriptRoot) 'lists'
$domDir = Join-Path $listsDir 'domains'
$ipsDir = Join-Path $listsDir 'ipsets'
if (-not (Test-Path -LiteralPath $ipsDir)) { New-Item -ItemType Directory -Path $ipsDir | Out-Null }
$services = @('discord','google','instagram','general')
foreach ($svc in $services) {
  $src = Join-Path $domDir ($svc + '.txt')
  if (-not (Test-Path -LiteralPath $src)) { Write-Output ('[SKIP] no ' + $svc + '.txt'); continue }
  $hosts = @(Get-Content -LiteralPath $src -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -notlike '^v*' -and $_ -notlike '#*' } | Where-Object { -not $_.StartsWith('^') })
  $ips = @{}
  $fail = @()
  foreach ($h in $hosts) {
    $got = $false
    foreach ($t in @('A','AAAA')) {
      try {
        $rr = Resolve-DnsName -Name $h -Type $t -ErrorAction Stop | Where-Object { $_.IPAddress }
        foreach ($r in $rr) {
          $ip = $r.IPAddress.ToString()
          if ($t -eq 'A') { $ips[$ip + '/32'] = $true } else { $ips[$ip + '/128'] = $true }
          $got = $true
        }
      } catch { }
    }
    if (-not $got) { $fail += @($h) }
  }
  $dst = Join-Path $ipsDir ($svc + '.txt')
  # UTF-8 no BOM via .NET (Set-Content -Encoding UTF8NoBOM does not exist on PS 5.1)
  [IO.File]::WriteAllLines($dst, @($ips.Keys | Sort-Object), (New-Object System.Text.UTF8Encoding $false))
  Write-Output ('[OK] ' + $svc + ': hosts=' + $hosts.Count + ' ips=' + $ips.Count + ' failed=' + $fail.Count)
  if ($fail.Count -gt 0 -and $fail.Count -le 12) { foreach ($x in $fail) { Write-Output ('  unresolved: ' + $x) } }
}
Write-Output 'DONE'
