<#
Helper script to try to compile the Inno Setup script if ISCC is installed.
It searches common install locations for ISCC.exe, otherwise prints instructions.
#>
Param(
  [string]$IssPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\saludandina_installer.iss"
)

Write-Host "Trying to locate ISCC (Inno Setup Compiler)..."

$candidates = @(
  "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "ISCC.exe"
)

$iscc = $null
foreach($p in $candidates){ if(Test-Path $p){ $iscc = $p; break } }

if(-not $iscc){
  Write-Warning "ISCC not found on PATH or common locations. Install Inno Setup (https://jrsoftware.org/) or run the compiler manually."
  Write-Host "You can compile the installer with (PowerShell):"
  Write-Host "  & 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' '$IssPath'"
  exit 2
}

Write-Host "Found ISCC at: $iscc"

$startDir = Get-Location
try{
  Set-Location (Split-Path -Parent $IssPath)
  & $iscc $IssPath
  $rc = $LASTEXITCODE
  if($rc -eq 0){ Write-Host "Installer compiled successfully." } else { Write-Warning "ISCC returned exit code $rc" }
} finally { Set-Location $startDir }
