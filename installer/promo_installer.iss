; Inno Setup script to install the `promo` website folder and create shortcuts to `index.html`
#define AppName "SaludAndina Promo"
#define AppVersion "1.0.0"
#define AppPublisher "SaludAndina"
#define OutputName "saludandina_setup"

[Setup]
AppId={{4B7F9F6E-3C9A-4E6D-9A2C-8B7D4C9F1234}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename={#OutputName}
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
WizardStyle=modern

[Files]
; Include the entire promo folder contents (relative to the script location)
Source: "..\promo\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
; Desktop shortcut that opens the local index.html with default browser
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\index.html"; WorkingDir: "{app}"
; Start Menu program group
Name: "{group}\{#AppName}"; Filename: "{app}\index.html"; WorkingDir: "{app}"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Opciones adicionales:"; Flags: unchecked

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\index.html"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\index.html"; Tasks: desktopicon

[Run]
; Optionally launch the index.html after installation
Filename: "{app}\index.html"; Description: "Abrir la página"; Flags: nowait postinstall skipifsilent
