# sync-presets.ps1 — pulls missing preset .bat files from author repos.
# Each Presets\<author>\repo.url holds the repo URL (empty = not configured).
# New files are auto-converted to root-relative form. ASCII-only.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Split-Path $PSScriptRoot
$presetsDir = Join-Path $rootDir 'Presets'
$conv = Join-Path $PSScriptRoot 'convert-preset.ps1'

# Flowseal release version check (informational)
$localVer = '1.10.3'
try {
  $rv = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt' -Headers @{'Cache-Control'='no-cache'} -TimeoutSec 8 -UseBasicParsing).Content.Trim()
  if ($rv -eq $localVer) { Write-Output ('[OK] Flowseal release: latest installed (' + $localVer + ')') }
  elseif ($rv) { Write-Output ('[NEW] Flowseal release available: ' + $rv + ' (local ' + $localVer + ') -> https://github.com/Flowseal/zapret-discord-youtube/releases/latest') }
} catch {
  Write-Output '[WARN] Could not check Flowseal version (network?)'
}

foreach ($dir in (Get-ChildItem -LiteralPath $presetsDir -Directory)) {
  $urlFile = Join-Path $dir.FullName 'repo.url'
  if (-not (Test-Path -LiteralPath $urlFile)) { continue }
  $repo = (Get-Content -LiteralPath $urlFile -Raw -Encoding UTF8).Trim()
  if (-not $repo) { Write-Output ('[SKIP] ' + $dir.Name + ': repo.url empty (author unknown)'); continue }
  if ($repo -notmatch 'github\.com/([^/]+)/([^/]+)') { Write-Output ('[SKIP] ' + $dir.Name + ': bad repo.url'); continue }
  $owner = $matches[1]; $repoName = $matches[2]
  Write-Output ('[INFO] ' + $dir.Name + ' <- ' + $owner + '/' + $repoName)
  # StressOzz keeps strategies in .md files (no .bat in repo root) — rebuild via converter
  if ($repo -match 'StressOzz/Zapret-Manager') {
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'convert-stressozz.ps1')
    } catch {
      Write-Output '  [WARN] convert-stressozz failed'
    }
    continue
  }
  try {
    $api = 'https://api.github.com/repos/' + $owner + '/' + $repoName + '/contents/'
    $items = Invoke-RestMethod -Uri $api -TimeoutSec 10
  } catch {
    Write-Output '  [WARN] GitHub API unreachable'; continue
  }
  $got = 0
  foreach ($it in $items) {
    if ($it.type -ne 'file' -or $it.name -notlike '*.bat') { continue }
    if ($it.name -like 'service*') { continue }
    $dst = Join-Path $dir.FullName $it.name
    if (Test-Path -LiteralPath $dst) { continue }
    try {
      $raw = 'https://raw.githubusercontent.com/' + $owner + '/' + $repoName + '/main/' + $it.name
      Invoke-WebRequest -Uri $raw -TimeoutSec 15 -UseBasicParsing -OutFile $dst
      & powershell -NoProfile -ExecutionPolicy Bypass -File $conv $dst | Out-Null
      Write-Output ('  [NEW] ' + $it.name)
      $got++
    } catch {
      Write-Output ('  [WARN] failed to download ' + $it.name)
    }
  }
  if ($got -eq 0) { Write-Output '  [OK] no new presets' }
}
Write-Output 'DONE'
