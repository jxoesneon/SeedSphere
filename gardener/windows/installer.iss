[Setup]
AppId={{D374B466-991A-4977-84C1-30D462973711}
AppName=SeedSphere Gardener
AppVersion=1.9.3
;AppVerName=SeedSphere Gardener 1.9.3
AppPublisher=SeedSphere
AppPublisherURL=https://seedsphere.app
AppSupportURL=https://seedsphere.app/support
AppUpdatesURL=https://seedsphere.app/downloads
DefaultDirName={autopf}\SeedSphere Gardener
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
OutputDir=..\build\windows\installer
OutputBaseFilename=gardener-setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\gardener.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\SeedSphere Gardener"; Filename: "{app}\gardener.exe"
Name: "{autodesktop}\SeedSphere Gardener"; Filename: "{app}\gardener.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\gardener.exe"; Description: "{cm:LaunchProgram,SeedSphere Gardener}"; Flags: nowait postinstall skipifsilent
