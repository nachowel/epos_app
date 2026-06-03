#define MyAppName "Halfway Cafe POS"
#define MyAppExeName "halfway_cafe_pos.exe"
#define MyAppPublisher "Halfway Cafe"
#define MyAppVersion "1.0.0"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{7A02B527-0E46-4F68-A4B4-5F2D1DFB7B9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Halfway Cafe POS
DefaultGroupName={#MyAppName}
OutputDir=..\output
OutputBaseFilename=EPOS-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
function RunBackupBeforeUpgrade(): Boolean;
var
  ExistingExe: String;
  ResultCode: Integer;
begin
  Result := True;
  ExistingExe := ExpandConstant('{app}\{#MyAppExeName}');

  if not FileExists(ExistingExe) then
  begin
    Log('No existing EPOS executable found; pre-install database backup skipped.');
    Exit;
  end;

  Log('Running EPOS pre-install database backup via installed app CLI.');
  Result := Exec(
    ExistingExe,
    '--backup-before-upgrade',
    ExpandConstant('{app}'),
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  if not Result then
  begin
    Log('Failed to execute EPOS backup CLI.');
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    Log(Format('EPOS backup CLI failed with exit code %d.', [ResultCode]));
    Result := False;
    Exit;
  end;

  Log('EPOS pre-install database backup completed successfully.');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';

  // The installer never runs SQL migrations. Drift migrations run only when
  // the app starts normally after installation.
  if not RunBackupBeforeUpgrade() then
  begin
    Result :=
      'Database backup failed. Setup will stop before updating the app. ' +
      'Close EPOS, check the Documents\backups folder permissions, and run Setup again.';
  end;
end;
