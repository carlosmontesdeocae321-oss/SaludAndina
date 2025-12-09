; Inno Setup script to package the Windows build of SaludAndina
#define AppName "SaludAndina"
#define AppVersion "2025.12.09"
#define AppPublisher "SaludAndina"
#define AppExeName "clinica_app.exe"

[Setup]
AppId={{63E38AF7-7A5B-4F68-8A58-DEF7D9D6B5E5}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename=SaludAndinaSetup_2025-12-09
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
DisableDirPage=no
DisableProgramGroupPage=no
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern

[Files]
; Copies the prepared Windows release folder (promo/windows_release)
Source: "..\promo\windows_release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Opciones adicionales:"; Flags: unchecked

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Iniciar {#AppName}"; Flags: nowait postinstall skipifsilent
