# update-service-ips.ps1 — IP ranges of major services via RIPEstat
# (ASN holders verified via as-overview: Telegram/AS62041,
# Facebook/AS32934, Twitter/AS13414).
# Writes lists\ipsets\<svc>.txt (IPv4 CIDRs, sorted unique, no BOM).
# Discord has no single verified ASN (snapshots in <svc>.txt cover it);
# amazon/cloudfront/cloudflare are handled by update-aws.ps1.
# Independent per-service steps: a failed source keeps its cache.
# ASCII-only, PS 5.1 safe.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$ipsDir = Join-Path $rootDir "lists\ipsets"

$services = @(
  @{ File='telegram.txt'; Asn='AS62041'; Name='Telegram' },
  @{ File='facebook.txt'; Asn='AS32934'; Name='Facebook' },
  @{ File='twitter.txt';  Asn='AS13414'; Name='Twitter' }
)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$summary = @()

foreach ($svc in $services) {
  $dest = Join-Path $ipsDir $svc.File
  $url = 'https://stat.ripe.net/data/announced-prefixes/data.json?resource=' + $svc.Asn
  try {
    $data = Invoke-RestMethod -Uri $url -TimeoutSec 25
    $cidrs = @($data.data.prefixes |
      ForEach-Object { $_.prefix } |
      Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$' } |
      Sort-Object -Unique)
    if ($cidrs.Count -eq 0) { throw "empty prefix list" }
    $old = 0
    if (Test-Path -LiteralPath $dest) {
      $old = @(Get-Content -LiteralPath $dest -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' }).Count
    }
    [IO.File]::WriteAllLines($dest, $cidrs, $utf8NoBom)
    Write-Host ("[OK] {0} ({1}): {2} CIDRs (was {3})." -f $svc.Name, $svc.Asn, $cidrs.Count, $old) -ForegroundColor Green
    $summary += ($svc.Name + ": $($cidrs.Count)")
  } catch {
    Write-Host ("[WARN] {0} ({1}) update failed ({2}). Cache kept." -f $svc.Name, $svc.Asn, $_) -ForegroundColor Yellow
    $summary += ($svc.Name + ": FAIL")
  }
}

Write-Host ""
Write-Host ("Summary: " + ($summary -join ' | '))
