$lines = Get-Content -LiteralPath "lib\screens\historial\historial_screen.dart"
$idx = 648
if ($idx -ge $lines.Length) { $idx = $lines.Length - 1 }
$slice = $lines[0..$idx] -join "`n"
$counts = [PSCustomObject]@{
  open_paren = ([regex]::Matches($slice,'\(')).Count
  close_paren = ([regex]::Matches($slice,'\)')).Count
  open_brace = ([regex]::Matches($slice,'\{')).Count
  close_brace = ([regex]::Matches($slice,'\}')).Count
  open_bracket = ([regex]::Matches($slice,'\[')).Count
  close_bracket = ([regex]::Matches($slice,'\]')).Count
}
$counts | Format-List
Write-Output "Total lines: $($lines.Length)"
