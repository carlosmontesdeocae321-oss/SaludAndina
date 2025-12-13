$BaseUrl = 'https://saludandina.onrender.com/api'

function Safe-PostJson($url, $body, $headers=@{}){
  $json = $body | ConvertTo-Json -Depth 10
  try{
    return Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $json -Headers $headers -ErrorAction Stop
  } catch {
    $resp = $_.Exception.Response
    if ($resp -ne $null) {
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $content = $reader.ReadToEnd()
      Write-Output "ERROR POST $url -> $content"
      return $null
    } else {
      Write-Output "ERROR POST $url -> $_"
      return $null
    }
  }
}

# 1) Crear doctor de prueba
$doctorUser = 'doc_e2e'
$doctorPass = 'Passw0rd!'
Write-Output "1) Creando doctor $doctorUser..."
$createDoc = Safe-PostJson "$BaseUrl/usuarios" @{ usuario=$doctorUser; clave=$doctorPass; rol='doctor' }
if ($createDoc -eq $null) { Write-Output 'Fallo creando doctor. Abortando.'; exit 1 }
Write-Output "Doctor creado: $($createDoc | ConvertTo-Json -Depth 3)"

# 2) Crear compra autenticada por el doctor
Write-Output "2) Creando compra autenticada por $doctorUser..."
$headers = @{ 'x-usuario' = $doctorUser; 'x-clave' = $doctorPass }
$compraBody = @{ titulo = 'Promoción: Clinica desde compra (E2E)'; monto = 1.0; provider = 'mock' }
$compraResp = Safe-PostJson "$BaseUrl/compras_promociones/crear" $compraBody $headers
if ($compraResp -eq $null -or -not $compraResp.compraId) { Write-Output 'Fallo creando compra. Abortando.'; exit 1 }
$compraId = $compraResp.compraId
Write-Output "Compra creada: ID = $compraId, payment_url = $($compraResp.payment_url)"

# 3) Confirmar compra (simulando webhook/frontend)
Write-Output "3) Confirmando compra $compraId..."
$confirmResp = Safe-PostJson "$BaseUrl/compras_promociones/confirmar" @{ compraId = $compraId }
if ($confirmResp -eq $null) { Write-Output 'Fallo confirmando compra. Abortando.'; exit 1 }
Write-Output "Confirm response: $($confirmResp | ConvertTo-Json -Depth 3)"

# 4) Enviar datos extra para crear clínica y vincular doctor
Write-Output "4) Enviando datos de la compra (nombre+direccion) para crear clínica..."
$datosBody = @{ nombre = 'Clinica E2E desde Compra'; direccion = 'Direccion E2E 123' }
$datosResp = Safe-PostJson "$BaseUrl/compras_promociones/$compraId/datos" $datosBody $headers
if ($datosResp -eq $null) { Write-Output 'Fallo enviando datos. Abortando.'; exit 1 }
Write-Output "Datos response: $($datosResp | ConvertTo-Json -Depth 3)"

# 5) Obtener compra completa para leer clinica_id
Write-Output "5) Obteniendo compra completa para recuperar clinica_id..."
try{
  $compFull = Invoke-RestMethod -Uri "$BaseUrl/compras_promociones/$compraId" -Method Get -Headers $headers -ErrorAction Stop
  Write-Output "Compra completa: $($compFull | ConvertTo-Json -Depth 5)"
} catch {
  Write-Output "No se pudo obtener compra completa: $_"
  exit 1
}
$clinicaId = $compFull.clinica_id
if (-not $clinicaId) { Write-Output 'clinica_id no presente en la compra. Abortando.'; exit 1 }
Write-Output "clinica_id obtenido: $clinicaId"

# 6) Verificar compras_doctores usuarios para la clinica
Write-Output "6) Consultando /api/compras_doctores/usuarios/$clinicaId ..."
try{
  $cd = Invoke-RestMethod -Uri "$BaseUrl/compras_doctores/usuarios/$clinicaId" -Method Get -ErrorAction Stop
  Write-Output "compras_doctores usuarios: $($cd | ConvertTo-Json -Depth 5)"
} catch { Write-Output "Error consultando compras_doctores: $_" }

# 7) Verificar clínica creada
Write-Output "7) Consultando /api/clinicas/$clinicaId ..."
try{
  $clinic = Invoke-RestMethod -Uri "$BaseUrl/clinicas/$clinicaId" -Method Get -ErrorAction Stop
  Write-Output "Clinica: $($clinic | ConvertTo-Json -Depth 5)"
} catch { Write-Output "Error consultando clinica: $_" }

Write-Output 'E2E completado.'
