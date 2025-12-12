$lines = Get-Content -LiteralPath 'lib\screens\historial\historial_screen.dart'
$balance = 0
$max = 0
$maxLine = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  $opens = ([regex]::Matches($line,'\(')).Count
  $closes = ([regex]::Matches($line,'\)')).Count
  $balance += $opens - $closes
  if ($balance -gt $max) { $max = $balance; $maxLine = $i+1 }
  if ($balance -lt 0) { Write-Output "Negative balance at line $($i+1) -> $balance"; break }
}
Write-Output "Final balance: $balance; max balance $max at line $maxLine"
