; Script para el instalador de Isan
[Setup]
AppName=Isan
AppVersion=1.0.1
AppPublisher=Isan Team
; AQUI ABAJO PEGARAS TU UUID
AppId=0647cc04-78cb-4a8c-ad4b-1f88e872e251
OutputDir=.\
OutputBaseFilename=Isan_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
DefaultDirName={autopf}\Isan
DisableProgramGroupPage=yes
PrivilegesRequired=admin

[Files]
; OJO: Asegúrate de que tu ejecutable se llame isan.exe. Si se llama diferente (ej: app.exe), cámbialo aquí.
Source: "..\build\windows\x64\runner\Release\isan.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Isan"; Filename: "{app}\isan.exe"
Name: "{autodesktop}\Isan"; Filename: "{app}\isan.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\isan.exe"; Description: "{cm:LaunchProgram,Isan}"; Flags: nowait postinstall skipifsilent