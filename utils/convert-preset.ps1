# convert-preset.ps1 — makes a preset .bat root-relative (ROOT = two levels up).
# Usage: convert-preset.ps1 <file.bat>  (positional arg, idempotent, ASCII-safe)
param([string]$Bat)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$t = Get-Content -LiteralPath $Bat -Raw -Encoding UTF8
if ($t -match 'set "ROOT=') { Write-Output ('SKIP (already converted): ' + $Bat); exit 0 }
$n = $t
$n = $n -replace '(?m)^cd /d "%~dp0"\r?$', ('$0' + "`r`n" + 'for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"')
$n = $n -replace 'call service\.bat', 'call "%ROOT%service.bat"'
$n = $n -replace 'set "BIN=%~dp0bin\\"', 'set "BIN=%ROOT%bin\"'
$n = $n -replace 'set "LISTS=%~dp0lists\\"', 'set "LISTS=%ROOT%lists\"'
$n = $n -replace 'set "AWS_LIST=%~dp0lists\\', 'set "AWS_LIST=%ROOT%lists\'
$n = $n -replace '"%~dp0update-aws\.ps1"', '"%ROOT%update-aws.ps1"'
# wire new service lists into general-coverage lines (idempotent, endings preserved)
$extraHosts = ' --hostlist="%LISTS%domains\telegram.txt" --hostlist="%LISTS%domains\twitter.txt" --hostlist="%LISTS%domains\facebook.txt"'
$parts = $n -split "(`r?`n)"
for ($i = 0; $i -lt $parts.Count; $i += 2) {
  if (($parts[$i] -match 'domains\\general\.txt"') -and ($parts[$i] -notmatch 'telegram\.txt')) {
    $parts[$i] = $parts[$i] -replace 'domains\\general\.txt"', ('domains\general.txt"' + $extraHosts)
  }
}
$n = $parts -join ''
if ($n -eq $t) { Write-Output ('WARN (no changes): ' + $Bat); exit 0 }
[IO.File]::WriteAllText($Bat, $n, $utf8NoBom)
Write-Output ('CONVERTED: ' + $Bat)
