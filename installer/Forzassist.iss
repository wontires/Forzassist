#define MyAppName "Forzassist"
#define MyAppPublisher "Forzassist"
#define MyAppExeName "Forzassist.exe"
#define ViGEmInstaller "ViGEmBus_1.22.0_x64_x86_arm64.exe"

[Setup]
AppId={{9812933A-CF51-4A08-A0CD-CC43F313A69C}
AppName={#MyAppName}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Forzassist_Setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMADictionarySize=1048576
LZMANumFastBytes=273
LZMANumBlockThreads=1
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\app\forzassist.ico
SetupIconFile=..\Forzassist\forzassist.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\dist_embedded\Forzassist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.obj,*.cpp.obj,*.pdb,*.ilk,*.exp,*.lib,*.a,*.pri,*.prl,*.h,*.hpp,*.qmltypes,*.pyi,*.typed,__pycache__\*,objects-Debug\*,objects-Release\*,objects-RelWithDebInfo\*,.qt\*,docs\*,doc\*,examples\*,tests\*,test\*,translations\*"
Source: "..\redist\{#ViGEmInstaller}"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: not IsViGEmBusInstalled

[Icons]
Name: "{group}\Forzassist"; Filename: "{app}\runtime\{#MyAppExeName}"; Parameters: """{app}\app\main.py"""; WorkingDir: "{app}\app"; IconFilename: "{app}\app\forzassist.ico"
Name: "{autodesktop}\Forzassist"; Filename: "{app}\runtime\{#MyAppExeName}"; Parameters: """{app}\app\main.py"""; WorkingDir: "{app}\app"; Tasks: desktopicon; IconFilename: "{app}\app\forzassist.ico"

[Run]
Filename: "{tmp}\{#ViGEmInstaller}"; Parameters: "/quiet /norestart"; StatusMsg: "Installing ViGEmBus virtual controller driver..."; Flags: waituntilterminated; Check: not IsViGEmBusInstalled
Filename: "{app}\runtime\{#MyAppExeName}"; Parameters: """{app}\app\main.py"""; WorkingDir: "{app}\app"; Description: "Launch Forzassist"; Flags: nowait postinstall skipifsilent

[Code]
function IsViGEmBusInstalled(): Boolean;
begin
  Result :=
    RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\ViGEmBus') or
    FileExists(ExpandConstant('{sys}\drivers\ViGEmBus.sys'));
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;
