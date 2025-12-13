$body = @'
{"nombre":"Clinica IVAR","direccion":"Direccion IVAR","usuario":"ivar","clave":"1236780"}
'@
try {
  $r = Invoke-RestMethod -Uri 'https://saludandina.onrender.com/api/compras_promociones/crear-clinica' -Method Post -ContentType 'application/json' -Body $body -ErrorAction Stop
  $r | ConvertTo-Json -Depth 5 | Write-Output
} catch {
  $resp = $_.Exception.Response
  if ($resp -ne $null) {
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $content = $reader.ReadToEnd()
    Write-Output 'ERROR-RESPONSE:'
    Write-Output $content
  } else {
    Write-Output $_.ToString()
  }
}
