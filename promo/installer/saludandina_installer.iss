; Inno Setup script to install the SaludAndina promo site files
; Installs files under {pf}\SaludAndina\promo and creates a Start Menu shortcut
[Setup]
AppName=SaludAndina Promo
AppVersion=1.0.0
DefaultDirName={pf}\SaludAndina\Promo
DefaultGroupName=SaludAndina
OutputBaseFilename=SaludAndina_Promo_Installer
Compression=lzma2/ultra64
SolidCompression=yes
WizardImageFile=

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"

[Files]
; Copy entire promo folder (all files in parent directory of this script)
Source: "..\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; Create shortcut in Start Menu that opens index.html in user's default browser
Name: "{group}\\SaludAndina Promo"; Filename: "{app}\\index.html"; WorkingDir: "{app}"; IconFilename: "{app}\\images\\saludandina_logo.png"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el Escritorio"; GroupDescription: "Opciones"; Flags: unchecked

[Icons]
Name: "{group}\\Abrir SaludAndina Promo"; Filename: "{app}\\index.html"; WorkingDir: "{app}"; MinVersion: 5.00
Name: "{group}\\Desinstalar SaludAndina Promo"; Filename: "{uninstallexe}"

[Run]
; Open readme after install (if present)
Filename: "{app}\\index.html"; Flags: shellexec nowait postinstall
