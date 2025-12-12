#!/usr/bin/env pwsh
# Create a doctor (public route) and a patient (using doctor credentials).
# Saves responses and any error bodies to files under the repository root.
Param(
    [string]$Usuario = 'ivargael',
    [string]$Clave = '1236780',
    [string]$BaseUrl = 'https://saludandina-1.onrender.com',
    [switch]$TryLogin  # If user exists, try login automatically
)

Set-StrictMode -Version Latest

function Save-TextFile($path, $text) {
    try { $text | Out-File -FilePath $path -Encoding utf8 -Force } catch { Write-Error "Failed writing $path : $_" }
}

function Invoke-JsonPost($url, $bodyJson, $headers = $null, [int]$timeoutSec = 30) {
    try {
        return Invoke-RestMethod -Uri $url -Method Post -Body $bodyJson -Headers $headers -ContentType 'application/json' -TimeoutSec $timeoutSec
    } catch {
        $err = $_
        $respText = $null
        try {
            if ($err.Exception.Response) {
                $stream = $err.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respText = $reader.ReadToEnd()
            }
        } catch { }
        throw ([PSCustomObject]@{ Exception = $err; Body = $respText })
    }
}

try {
    $ts = Get-Date -Format yyyyMMddHHmmss
    Write-Output "Timestamp: $ts"

    # 1) Create doctor
    $doctorBody = @{ usuario = $Usuario; clave = $Clave; rol = 'doctor' } | ConvertTo-Json
    $doctorOut = ".\doctor_create_response_$ts.json"
    $doctorErr = ".\doctor_create_error_$ts.txt"

    $createdDoctor = $null
    Write-Output "Creating doctor '$Usuario'..."
    try {
        $resp = Invoke-JsonPost "$BaseUrl/api/usuarios" $doctorBody
        $resp | ConvertTo-Json -Depth 6 | Out-File -FilePath $doctorOut -Encoding utf8
        Write-Output "Doctor created, response saved to $doctorOut"
        $createdDoctor = $resp
    } catch {
        $e = $_.Exception
        # If the helper re-threw a PSCustomObject with Body, extract
        $bodyText = $null
        if ($_.Exception -is [PSCustomObject]) {
            $bodyText = $_.Exception.Body
        } else {
            try { $bodyText = $_.Exception.Response.GetResponseStream() | ForEach-Object { $_ } } catch { }
        }
        if ($bodyText) { Save-TextFile $doctorErr $bodyText } else { Save-TextFile $doctorErr ($_.ToString()) }
        Write-Output "Doctor create failed, details saved to $doctorErr"

        # Detect duplicate username
        $errBody = Get-Content -Raw -ErrorAction SilentlyContinue $doctorErr
        $isDup = $false
        if ($errBody -and ($errBody -match 'usuario' -or $errBody -match 'ya existe' -or $errBody -match 'ER_DUP_ENTRY')) { $isDup = $true }

        if ($isDup -and $TryLogin) {
            Write-Output "User already exists; attempting login because -TryLogin was passed..."
            try {
                $loginBody = @{ usuario = $Usuario; clave = $Clave } | ConvertTo-Json
                $loginResp = Invoke-JsonPost "$BaseUrl/api/usuarios/login" $loginBody
                $loginResp | ConvertTo-Json -Depth 6 | Out-File -FilePath ".\doctor_login_response_$ts.json" -Encoding utf8
                Write-Output "Login successful; response saved to .\doctor_login_response_$ts.json"
                $createdDoctor = $loginResp
            } catch {
                $loginErr = Get-Date -Format yyyyMMddHHmmss
                $msg = "Login attempt failed for existing user: $($_.ToString())"
                Save-TextFile ".\doctor_login_error_$ts.txt" $msg
                Write-Output "Login failed; details saved to .\doctor_login_error_$ts.txt"
                throw "Cannot continue without valid doctor credentials."
            }
        } else {
            throw "Doctor creation failed and not recoverable. See $doctorErr"
        }
    }

    # Determine effective credentials to use
    $useUsuario = $Usuario
    $useClave = $Clave
    # If login returned a different username field, keep using provided credentials (server expects x-usuario/x-clave)

    # 2) Create patient using doctor credentials
    $patientTs = Get-Date -Format yyyyMMddHHmmss
    $headers = @{ 'x-usuario' = $useUsuario; 'x-clave' = $useClave }
    $pacientePayload = @{ 
        nombres = "PacienteAuto",
        apellidos = "Prueba$patientTs",
        cedula = "$patientTs",
        telefono = "999$($patientTs.Substring($patientTs.Length-6))",
        client_local_id = "local-p-$patientTs"
    } | ConvertTo-Json

    $pOut = ".\paciente_create_response_$patientTs.json"
    $pErr = ".\paciente_create_error_$patientTs.txt"

    try {
        $pr = Invoke-JsonPost "$BaseUrl/api/pacientes" $pacientePayload $headers
        $pr | ConvertTo-Json -Depth 6 | Out-File -FilePath $pOut -Encoding utf8
        Write-Output "Paciente creado, respuesta guardada en $pOut"

        # Try to extract patient id
        $patientId = $null
        if ($pr -and $pr.data -and $pr.data.id) { $patientId = $pr.data.id }
        elseif ($pr.id) { $patientId = $pr.id }

        if ($patientId) {
            Write-Output "Patient id: $patientId -- attempting GET to validate..."
            try {
                $get = Invoke-RestMethod -Uri "$BaseUrl/api/pacientes/$patientId" -Method Get -Headers $headers -TimeoutSec 20
                $gOut = ".\paciente_get_$patientId.json"
                $get | ConvertTo-Json -Depth 6 | Out-File -FilePath $gOut -Encoding utf8
                Write-Output "Paciente leído OK, guardado en $gOut"
            } catch {
                Write-Output "Warning: could not GET paciente/$patientId : $($_.Exception.Message)"
            }
        } else {
            Write-Output "Notice: no patient id found in response. Inspect $pOut"
        }

    } catch {
        $err = $_
        $bodyText = $null
        if ($err.Exception -is [PSCustomObject]) { $bodyText = $err.Exception.Body }
        if (-not $bodyText) { $bodyText = $_.ToString() }
        Save-TextFile $pErr $bodyText
        Write-Output "Paciente create failed; details saved to $pErr"
        throw "Paciente creation failed"
    }

    Write-Output "All done. Check the generated JSON/text files for details."

} catch {
    Write-Error "Script failed: $_"
    exit 1
}
