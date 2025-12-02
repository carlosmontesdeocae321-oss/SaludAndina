# Script para commitear y pushear los cambios del backend
# Úsalo desde la raíz del proyecto: C:\Users\DarthRoberth\clinica_app
# ADVERTENCIA: Añade tu remoto antes de hacer push, o edita el valor de $remoteUrl

# Mensaje de commit predefinido
$commitMessage = "Integrate Cloudinary: add service, update controllers/routes, add dotenv and .env.example, ensure upload dirs exist"

# Nombre del remoto (ajusta si usas otro)
# Remote name to push to
$remoteName = 'origin'
# Si no tienes remoto, pon aquí la URL del repositorio (ej: https://github.com/usuario/repo.git)
# Hecha a tu repo proporcionado
$remoteUrl = 'https://github.com/carlosmontesdeocae321-oss/SaludAndinaBackend.git'

Write-Host "1) Asegurando que estamos en la carpeta del proyecto..."
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ErrorAction SilentlyContinue
# Cambiar al path donde se encuentra este script (scripts), luego subir a la raíz del repo
Set-Location ..\

Write-Host "Directorio actual: $(pwd)"

# Inicializar git si no existe
if (-not (Test-Path .git)) {
    Write-Host "Inicializando repositorio git..."
    git init
} else {
    Write-Host ".git ya existe"
}

# Añadir remoto si no existe y si $remoteUrl está configurado
if ($remoteUrl -ne '') {
    $existing = git remote | Where-Object { $_ -eq $remoteName }
    if (-not $existing) {
        git remote add $remoteName $remoteUrl
        Write-Host "Remoto añadido: $remoteUrl"
    } else {
        Write-Host "Remoto $remoteName ya existe"
    }
} else {
    Write-Host 'No se configuró remoteUrl en el script. Si deseas pushear, configura la variable `$remoteUrl` en este script o añade manualmente un remoto con: git remote add origin <url>'
}

# Añadir y commitear
Write-Host "Añadiendo cambios..."
git add -A

Write-Host "Creando commit..."
if ((git status --porcelain) -ne '') {
    git commit -m "$commitMessage"
    Write-Host "Commit creado"
} else {
    Write-Host "No hay cambios para commitear"
}

# Detectar rama actual para pushear (usar 'main' si no hay rama)
$branch = ''
try {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
} catch {
    $branch = ''
}
if (-not $branch -or $branch -eq 'HEAD') {
    # No hay rama actual (repositorio nuevo), usar 'main'
    $branch = 'main'
    # Crear y moverse a la rama main si no existe
    try {
        git rev-parse --verify $branch 2>$null | Out-Null
    } catch {
        git checkout -b $branch
    }
}

# Push (solo si hay remoto configurado)
$existingRemote = git remote | Where-Object { $_ -eq $remoteName }
if ($existingRemote) {
    Write-Host "Haciendo push al remoto '$remoteName' en la rama '$branch'..."
    git push -u $remoteName $branch
} else {
    Write-Host "No hay remoto configurado. Ejecuta: git remote add origin <url> ; git push -u origin $branch"
}

Write-Host "Hecho. Revisa la salida de los comandos para confirmar éxito."