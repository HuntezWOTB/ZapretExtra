# Set UTF-8 output encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Step 1: amazon.txt = curated cache UNION official AWS ranges.
# Old upstream (V3nilla ipset-amazon.txt) is dead (repo restructured, 404).
# New source: https://ip-ranges.amazonaws.com/ip-ranges.json, services AMAZON+EC2.
# We UNION with the cached file (never delete curated entries: old list holds
# 2808 entries, only 785 overlap official ranges). Steps are independent:
# a failed step keeps its cache and never blocks the other step.
$listPath = Join-Path -Path $PSScriptRoot -ChildPath "lists\ipsets\amazon.txt"
$awsOfficialUrl = "https://ip-ranges.amazonaws.com/ip-ranges.json"
$step1Ok = $false

try {
    $aws = Invoke-RestMethod -Uri $awsOfficialUrl -TimeoutSec 25
    $official = @($aws.prefixes | Where-Object { $_.service -eq 'AMAZON' -or $_.service -eq 'EC2' } |
        ForEach-Object { $_.ip_prefix } |
        Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$' } |
        Sort-Object -Unique)
    if ($official.Count -eq 0) { throw "empty official list" }

    $cached = @()
    if (Test-Path -LiteralPath $listPath) {
        $cached = @(Get-Content -LiteralPath $listPath -Encoding UTF8 -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(/\d{1,2})?$' })
    }
    $merged = @((@($official) + @($cached)) | Sort-Object -Unique)

    $dir = Split-Path -Path $listPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllLines($listPath, $merged, $utf8NoBom)
    Write-Host ("[INFO] amazon.txt updated: official={0} cached={1} merged={2}." -f $official.Count, $cached.Count, $merged.Count)
    $step1Ok = $true
}
catch {
    Write-Host ("[ERROR] Amazon update failed ({0}). Retaining cached list." -f $_)
}

# --- Step 2: CloudFront official IP list -> lists\ipsets\cloudfront.txt ---
# Primary : https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips
#           (JSON: CLOUDFRONT_GLOBAL_IP_LIST + CLOUDFRONT_REGIONAL_EDGE_IP_LIST)
# Fallback: https://ip-ranges.amazonaws.com/ip-ranges.json (service == CLOUDFRONT)
# Independent step: failure here keeps cached file and does NOT fail the script.
$cfPath = Join-Path -Path $PSScriptRoot -ChildPath "lists\ipsets\cloudfront.txt"
$cfUrl = "https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips"
$cfOk = $false

function Save-CidrList($cidrs, $dest, $src) {
    $clean = @($cidrs | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$' } | Sort-Object -Unique)
    if ($clean.Count -eq 0) { throw "empty cidr list from $src" }
    $dir = Split-Path -Path $dest
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    # UTF-8 no BOM via .NET (Out-File -Encoding utf8NoBOM does not exist on PS 5.1)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllLines($dest, $clean, $utf8NoBom)
    Write-Host ("[INFO] CloudFront list updated from {0}. {1} CIDRs saved." -f $src, $clean.Count)
}

try {
    $cf = Invoke-RestMethod -Uri $cfUrl -TimeoutSec 15
    $cidrs = @()
    if ($cf.CLOUDFRONT_GLOBAL_IP_LIST) { $cidrs += $cf.CLOUDFRONT_GLOBAL_IP_LIST }
    if ($cf.CLOUDFRONT_REGIONAL_EDGE_IP_LIST) { $cidrs += $cf.CLOUDFRONT_REGIONAL_EDGE_IP_LIST }
    Save-CidrList $cidrs $cfPath "cloudfront-ips"
    $cfOk = $true
}
catch {
    Write-Host "[WARN] Primary CloudFront source failed ($_). Trying official AWS ip-ranges.json..."
    try {
        $aws = Invoke-RestMethod -Uri $awsOfficialUrl -TimeoutSec 20
        $cidrs = @($aws.prefixes | Where-Object { $_.service -eq 'CLOUDFRONT' } | ForEach-Object { $_.ip_prefix })
        Save-CidrList $cidrs $cfPath "ip-ranges.json"
        $cfOk = $true
    }
    catch {
        Write-Host "[WARN] CloudFront update failed. Retaining cached list."
    }
}

Write-Host ("[INFO] Summary: amazon={0} cloudfront={1}." -f $(if ($step1Ok) { 'updated' } else { 'cached' }), $(if ($cfOk) { 'updated' } else { 'cached' }))
if (-not $step1Ok) { exit 1 }
