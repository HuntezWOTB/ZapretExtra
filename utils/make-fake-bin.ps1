# make-fake-bin.ps1 — generates per-domain fake .bin files
# TLS: patches SNI inside a captured ClientHello (fixes all length fields).
# QUIC Initial payload is encrypted (SNI invisible), so per-domain variants
# only randomize cleartext header fields (DCID + packet number), keeping a
# well-formed 1200-byte Initial. Run manually when new fakes are needed.
# ASCII-only (PS 5.1 safe).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$binDir = Join-Path (Split-Path $PSScriptRoot) 'bin'
$tlsDir = Join-Path $binDir 'tls_clienthello'
$quicDir = Join-Path $binDir 'quic_initial'

function Read-Varint($b, $pos) {
  $first = $b[$pos]
  $pfx = ($first -shr 6) -band 3
  if ($pfx -eq 0) { return @(($first -band 0x3F), 1) }
  if ($pfx -eq 1) { return @((($first -band 0x3F) * 256 + $b[$pos+1]), 2) }
  if ($pfx -eq 2) {
    $v = ($first -band 0x3F); for ($i=1; $i-lt 4; $i++) { $v = $v*256 + $b[$pos+$i] }
    return @($v, 4)
  }
  $v = ($first -band 0x3F); for ($i=1; $i-lt 8; $i++) { $v = $v*256 + $b[$pos+$i] }
  return @($v, 8)
}

function Find-Sni($b) {
  # returns @{nameOff, nameLen, lenFields} or $null; lenFields = @(off,size) list to grow by delta
  if ($b[0] -ne 0x16 -or $b[5] -ne 0x01) { return $null }
  $recLen = $b[3]*256 + $b[4]
  $hsLen = $b[6]*65536 + $b[7]*256 + $b[8]
  if ($recLen + 5 -ne $b.Length) { return $null }
  $pos = 9 + 2 + 32
  if ($pos -ge $b.Length) { return $null }
  $sidLen = $b[$pos]; $pos += 1 + $sidLen
  $csLen = $b[$pos]*256 + $b[$pos+1]; $pos += 2 + $csLen
  $cmLen = $b[$pos]; $pos += 1 + $cmLen
  $extTotalLen = $b[$pos]*256 + $b[$pos+1]
  $extTotalOff = $pos
  $pos += 2
  $extEnd = $extTotalOff + 2 + $extTotalLen
  while ($pos + 4 -le $extEnd) {
    $etype = $b[$pos]*256 + $b[$pos+1]
    $elen = $b[$pos+2]*256 + $b[$pos+3]
    if ($etype -eq 0) {
      $listLen = $b[$pos+4]*256 + $b[$pos+5]
      $p2 = $pos + 6
      if ($b[$p2] -eq 0) {
        $nameLen = $b[$p2+1]*256 + $b[$p2+2]
        $nameOff = $p2 + 3
        $name = [Text.Encoding]::ASCII.GetString($b[$nameOff..($nameOff+$nameLen-1)])
        $fName = $p2 + 1
        $fList = $pos + 4
        $fExt = $pos + 2
        return @{
          name = $name; nameOff = $nameOff; nameLen = $nameLen
          fields = @(@($fName,2), @($fList,2), @($fExt,2), @($extTotalOff,2), @($extTotalOff,0))
          recLenOff = 3; hsLenOff = 6; oldRecLen = $recLen; oldHsLen = $hsLen
        }
      }
      return $null
    }
    $pos += 4 + $elen
  }
  return $null
}

function Set-Sni($srcPath, $dstPath, $newHost) {
  $b = [IO.File]::ReadAllBytes($srcPath)
  $info = Find-Sni $b
  if (-not $info) { throw ("no SNI in " + $srcPath) }
  $newBytes = [Text.Encoding]::ASCII.GetBytes($newHost)
  $delta = $newBytes.Length - $info.nameLen
  $out = New-Object Collections.Generic.List[byte]
  # head before name
  for ($i = 0; $i -lt $info.nameOff; $i++) { $out.Add($b[$i]) }
  foreach ($x in $newBytes) { $out.Add($x) }
  for ($i = $info.nameOff + $info.nameLen; $i -lt $b.Length; $i++) { $out.Add($b[$i]) }
  $arr = $out.ToArray()
  # fix lengths: name(2B), list(2B), ext(2B), extTotal(2B) [+delta]; hs(3B), rec(2B) [+delta]
  foreach ($f in $info.fields) {
    $off = $f[0]
    if ($off -eq $info.fields[4][0]) { continue } # placeholder, skip
    $cur = $arr[$off]*256 + $arr[$off+1]
    $nv = $cur + $delta
    $arr[$off] = [byte](($nv -shr 8) -band 0xFF); $arr[$off+1] = [byte]($nv -band 0xFF)
  }
  $nhs = $info.oldHsLen + $delta
  $arr[$info.hsLenOff] = [byte](($nhs -shr 16) -band 0xFF); $arr[$info.hsLenOff+1] = [byte](($nhs -shr 8) -band 0xFF); $arr[$info.hsLenOff+2] = [byte]($nhs -band 0xFF)
  $nrec = $info.oldRecLen + $delta
  $arr[$info.recLenOff] = [byte](($nrec -shr 8) -band 0xFF); $arr[$info.recLenOff+1] = [byte]($nrec -band 0xFF)
  [IO.File]::WriteAllBytes($dstPath, $arr)
  # validate: reparse
  $chk = Find-Sni $arr
  if (-not $chk -or $chk.name -ne $newHost) { throw ("validate failed for " + $dstPath) }
  return $arr.Length
}

function New-QuicVariant($srcPath, $dstPath) {
  $b = [IO.File]::ReadAllBytes($srcPath)
  if (($b[0] -band 0xC0) -ne 0xC0) { throw 'not a QUIC long header' }
  $pnLen = ($b[0] -band 3) + 1
  $dcidLen = $b[5]
  $pos = 6 + $dcidLen
  $scidLen = $b[$pos]; $pos += 1 + $scidLen
  $r1 = Read-Varint $b $pos; $tokLen = $r1[0]; $pos += $r1[1] + $tokLen
  $r2 = Read-Varint $b $pos; $payLen = $r2[0]; $pos += $r2[1]
  if ($pos + $payLen -ne $b.Length) { throw ("QUIC len mismatch: pos=" + $pos + " pay=" + $payLen + " total=" + $b.Length) }
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  $nb = $b.Clone()
  $dc = New-Object byte[] $dcidLen; $rng.GetBytes($dc)
  [Array]::Copy($dc, 0, $nb, 6, $dcidLen)
  $pn = New-Object byte[] $pnLen; $rng.GetBytes($pn)
  [Array]::Copy($pn, 0, $nb, $pos, $pnLen)
  [IO.File]::WriteAllBytes($dstPath, $nb)
  $rng.Dispose()
  return $nb.Length
}

# self-test: identity patch must be byte-identical
$tlsTpl = Join-Path $tlsDir 'tls_clienthello_www_google_com.bin'
$quicTpl = Join-Path $quicDir 'quic_initial_www_google_com.bin'
$tmp = [IO.Path]::GetTempFileName()
$selfLen = Set-Sni $tlsTpl $tmp 'www.google.com'
$orig = [IO.File]::ReadAllBytes($tlsTpl)
$self = [IO.File]::ReadAllBytes($tmp)
$same = ($orig.Length -eq $self.Length)
if ($same) { for ($i = 0; $i -lt $orig.Length; $i++) { if ($orig[$i] -ne $self[$i]) { $same = $false; break } } }
Remove-Item -LiteralPath $tmp -Force
if (-not $same) { throw 'TLS self-test FAILED' }
Write-Output 'TLS self-test OK (identity patch byte-identical)'
$tmp2 = [IO.Path]::GetTempFileName()
New-QuicVariant $quicTpl $tmp2 | Out-Null
$qv = [IO.File]::ReadAllBytes($tmp2)
if ($qv.Length -ne 1200) { throw 'QUIC self-test FAILED (len)' }
Remove-Item -LiteralPath $tmp2 -Force
Write-Output 'QUIC self-test OK (1200 bytes, header valid)'

$domains = @('vk.ru','yandex.ru','mail.ru','rutube.ru','max.ru','lolka.app','vkvideo.ru','vk.com','gosuslugi.ru')
foreach ($d in $domains) {
  $flat = $d -replace '\.', '_'
  $tp = Join-Path $tlsDir ("tls_clienthello_" + $flat + ".bin")
  $qp = Join-Path $quicDir ("quic_initial_" + $flat + ".bin")
  $tl = Set-Sni $tlsTpl $tp $d
  $ql = New-QuicVariant $quicTpl $qp
  Write-Output ("made " + (Split-Path $tp -Leaf) + " len=" + $tl + " + " + (Split-Path $qp -Leaf) + " len=" + $ql)
}
Write-Output 'DONE'
