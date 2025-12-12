$ErrorActionPreference = 'Stop'
$base = 'https://saludandina-1.onrender.com'
$ts = Get-Date -Format yyyyMMddHHmmss
$docUser = "autotestdoc_$ts"
$docPass = 'Autotest123!'
Write-Output "=== START TEST $ts ==="
# 1) Create doctor individual
$body = @{ usuario = $docUser; clave = $docPass; rol = 'doctor' } | ConvertTo-Json
Write-Output "-- Creating doctor: $docUser"
try {
  $r = Invoke-WebRequest -Uri "$base/api/usuarios" -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30
  $doctorCreate = $r.Content | ConvertFrom-Json
  Write-Output "DOCTOR_CREATED_STATUS: $($r.StatusCode) $($r.StatusDescription)"
  Write-Output "DOCTOR_CREATED_BODY: $($r.Content)"
} catch {
  Write-Output "DOCTOR_CREATE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
  exit 1
}

# 2) Create patient
$headers = @{ 'x-usuario' = $docUser; 'x-clave' = $docPass; 'Content-Type' = 'application/json' }
$pacientePayload = @{ nombres = "PacienteAuto"; apellidos = "Prueba$ts"; cedula = "$ts"; telefono = "999$($ts.Substring($ts.Length-6))"; client_local_id = "local-p-$ts" } | ConvertTo-Json
Write-Output "-- Creating patient"
try {
  $r2 = Invoke-WebRequest -Uri "$base/api/pacientes" -Method Post -Headers $headers -Body $pacientePayload -UseBasicParsing -TimeoutSec 30
  Write-Output "PATIENT_CREATE_STATUS: $($r2.StatusCode) $($r2.StatusDescription)"
  Write-Output "PATIENT_CREATE_BODY: $($r2.Content)"
  $patientCreate = $r2.Content | ConvertFrom-Json
} catch {
  Write-Output "PATIENT_CREATE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
  exit 1
}

# Extract patient id
$patientId = $null
if ($patientCreate -is [System.Collections.IDictionary] -and $patientCreate.ContainsKey('data')) {
  $patientId = $patientCreate.data.id
} elseif ($patientCreate.id) { $patientId = $patientCreate.id }
Write-Output "PATIENT_ID: $patientId"

# 3) Read patient
Write-Output "-- Reading patient $patientId"
try {
  $r3 = Invoke-WebRequest -Uri "$base/api/pacientes/$patientId" -Method Get -Headers $headers -UseBasicParsing -TimeoutSec 20
  Write-Output "PATIENT_READ_STATUS: $($r3.StatusCode) $($r3.StatusDescription)"
  Write-Output "PATIENT_READ_BODY: $($r3.Content)"
} catch {
  Write-Output "PATIENT_READ_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

# 4) Update patient
Write-Output "-- Updating patient $patientId"
$updatePayload = @{ telefono = "888$($ts.Substring($ts.Length-6))"; apellidos = "PruebaUpdated$ts" } | ConvertTo-Json
try {
  $r4 = Invoke-WebRequest -Uri "$base/api/pacientes/$patientId" -Method Put -Headers $headers -Body $updatePayload -ContentType 'application/json' -UseBasicParsing -TimeoutSec 20
  Write-Output "PATIENT_UPDATE_STATUS: $($r4.StatusCode) $($r4.StatusDescription)"
  Write-Output "PATIENT_UPDATE_BODY: $($r4.Content)"
} catch {
  Write-Output "PATIENT_UPDATE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

# 5) Create historial for patient
Write-Output "-- Creating historial for patient $patientId"
$histPayload = @{ paciente_id = $patientId; motivo_consulta = "Prueba automatizada"; notas_html = "<p>Nota prueba</p>"; fecha = (Get-Date).ToString('s'); client_local_id = "local-h-$ts" } | ConvertTo-Json
try {
  $r5 = Invoke-WebRequest -Uri "$base/api/historial" -Method Post -Headers $headers -Body $histPayload -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30
  Write-Output "HIST_CREATE_STATUS: $($r5.StatusCode) $($r5.StatusDescription)"
  Write-Output "HIST_CREATE_BODY: $($r5.Content)"
  $histCreate = $r5.Content | ConvertFrom-Json
} catch {
  Write-Output "HIST_CREATE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
  exit 1
}

# Extract historial id
$histId = $null
if ($histCreate -is [System.Collections.IDictionary] -and $histCreate.ContainsKey('data')) { $histId = $histCreate.data.id } elseif ($histCreate.id) { $histId = $histCreate.id }
Write-Output "HIST_ID: $histId"

# 6) Read historial
Write-Output "-- Reading historial $histId"
try {
  $r6 = Invoke-WebRequest -Uri "$base/api/historial/$histId" -Method Get -Headers $headers -UseBasicParsing -TimeoutSec 20
  Write-Output "HIST_READ_STATUS: $($r6.StatusCode) $($r6.StatusDescription)"
  Write-Output "HIST_READ_BODY: $($r6.Content)"
} catch {
  Write-Output "HIST_READ_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

# 7) Update historial
Write-Output "-- Updating historial $histId"
$histUpd = @{ motivo_consulta = "Prueba modificada" } | ConvertTo-Json
try {
  $r7 = Invoke-WebRequest -Uri "$base/api/historial/$histId" -Method Put -Headers $headers -Body $histUpd -ContentType 'application/json' -UseBasicParsing -TimeoutSec 20
  Write-Output "HIST_UPDATE_STATUS: $($r7.StatusCode) $($r7.StatusDescription)"
  Write-Output "HIST_UPDATE_BODY: $($r7.Content)"
} catch {
  Write-Output "HIST_UPDATE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

# 8) Delete historial
Write-Output "-- Deleting historial $histId"
try {
  $r8 = Invoke-WebRequest -Uri "$base/api/historial/$histId" -Method Delete -Headers $headers -UseBasicParsing -TimeoutSec 20
  Write-Output "HIST_DELETE_STATUS: $($r8.StatusCode) $($r8.StatusDescription)"
  Write-Output "HIST_DELETE_BODY: $($r8.Content)"
} catch {
  Write-Output "HIST_DELETE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

# 9) Delete patient (if allowed)
Write-Output "-- Attempting to delete patient $patientId"
try {
  $r9 = Invoke-WebRequest -Uri "$base/api/pacientes/$patientId" -Method Delete -Headers $headers -UseBasicParsing -TimeoutSec 20
  Write-Output "PATIENT_DELETE_STATUS: $($r9.StatusCode) $($r9.StatusDescription)"
  Write-Output "PATIENT_DELETE_BODY: $($r9.Content)"
} catch {
  Write-Output "PATIENT_DELETE_ERROR: $($_.Exception.Message)"
  if ($_.Exception.Response) { $resp = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($resp); Write-Output $reader.ReadToEnd() }
}

Write-Output "=== END TEST $ts ==="
