param(
  [string]$BaseUrl = $(throw 'Debe proporcionar BaseUrl, p.ej. https://miapp.onrender.com'),
  [string]$User = 'lora',
  [string]$Pass = '1236780',
  [int]$DoctorId = 7
)

Write-Host "BaseUrl: $BaseUrl"
Write-Host "User: $User, DoctorId: $DoctorId"

function ApiPost($url, $body, $headers) {
  return Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ($body | ConvertTo-Json) -ContentType 'application/json' -ErrorAction Stop
}

function ApiGet($url, $headers) {
  return Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ContentType 'application/json' -ErrorAction Stop
}

try {
  $loginUrl = "$BaseUrl/api/usuarios/login"
  Write-Host "1) Iniciando sesión como $User..."
  $loginBody = @{ usuario = $User; clave = $Pass }
  $loginResp = ApiPost $loginUrl $loginBody @{}
  Write-Host "Login OK: id=$($loginResp.id), rol=$($loginResp.rol), clinicaId=$($loginResp.clinicaId), dueno=$($loginResp.dueno)"

  $headers = @{ 'x-usuario' = $User; 'x-clave' = $Pass }

  Write-Host "2) Obteniendo compras del usuario..."
  $misUrl = "$BaseUrl/api/compras_promociones/mis"
  $mis = ApiGet $misUrl $headers
  if (-not $mis) { Write-Host "No hay compras (respuesta vacía)."; exit 0 }
  $pendientes = @()
  foreach ($c in $mis) { if ((($c.status -as [string]) -ne 'completed') -and (($c.status -as [string]) -ne 'completed\r')) { $pendientes += $c } }

  if ($pendientes.Count -eq 0) {
    Write-Host "No hay compras pendientes en la cuenta de $User."; exit 0
  }

  Write-Host "Compras pendientes encontradas: $($pendientes.Count)"
  foreach ($p in $pendientes) {
    Write-Host "-> Procesando compra id=$($p.id) titulo=$($p.titulo)"
    # Confirmar compra (admin/owner)
    $confirmUrl = "$BaseUrl/api/compras_promociones/admin/confirm"
    try {
      $confirmResp = ApiPost $confirmUrl @{ compraId = $p.id } $headers
      Write-Host "   confirmada compra $($p.id):", ($confirmResp | ConvertTo-Json -Depth 3)
    } catch {
      Write-Host "   Error confirmando compra $($p.id): $($_.Exception.Message)"; continue
    }

    # Intentar vincular doctor al clinica del usuario (si login devolvió clinicaId)
    $clinicaId = $loginResp.clinicaId
    if (-not $clinicaId) {
      Write-Host "   No se encontró clinicaId en el usuario. Saltando vinculación."; continue
    }

    $vincUrl = "$BaseUrl/api/vinculacion_doctor/vincular-doctor"
    try {
      $vResp = ApiPost $vincUrl @{ doctor_id = $DoctorId; clinica_id = $clinicaId } $headers
      Write-Host "   Vinculación realizada: $($vResp | ConvertTo-Json -Depth 3)"
    } catch {
      Write-Host "   Error vinculando doctor $DoctorId a clinica $clinicaId: $($_.Exception.Message)"
    }
  }

  Write-Host "Proceso finalizado.";
} catch {
  Write-Host "Error general: $($_.Exception.Message)"
  exit 1
}
