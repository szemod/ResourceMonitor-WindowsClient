; -- installer.iss --
; Inno Setup script for ResourceMonitorInstaller

[Setup]
AppName=Resource Monitor
AppVersion=1.0
AppId={code:GetAppId}
DefaultDirName={code:GetDefaultDirName}  ; alapértelmezett: C:\Apps\ResourceMonitor
DefaultGroupName=Resource Monitor
UninstallDisplayIcon={app}\nssm.exe
OutputBaseFilename=ResourceMonitorInstaller
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=userdocs: Inno Setup Output
UsePreviousLanguage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "monitor.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "templates\*"; DestDir: "{app}\templates"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "nssm.exe"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; Lekéri a Python elérési útját
Filename: "cmd.exe"; Parameters: "/C where python > ""{tmp}\python_path.txt"""; Flags: runhidden
; Másolás: a monitor.py-ból készítünk resource_monitor.py-t
Filename: "cmd.exe"; Parameters: "/C copy ""{app}\monitor.py"" ""{app}\resource_monitor.py"""; Flags: runhidden; StatusMsg: "Másolás a resource_monitor.py fájlhoz..."
; Kódolás konverzió: resource_monitor.py átkonvertálása UTF-8-ra
Filename: "powershell.exe"; Parameters: "-Command ""Get-Content -Path '{app}\resource_monitor.py' | Set-Content -Path '{app}\resource_monitor.py' -Encoding UTF8"""; Flags: runhidden; StatusMsg: "UTF-8 kódolás beállítása a resource_monitor.py fájlnál..."
; Szolgáltatás telepítése: resource_monitor.py fájl használata
Filename: "{app}\nssm.exe"; Parameters: "install ""{code:GetServiceName}"" ""{app}\venv\Scripts\python.exe"" ""{app}\resource_monitor.py"""; WorkingDir: "{app}"; Flags: runhidden; StatusMsg: "Resource Monitor szolgáltatás telepítése..."
; Szolgáltatás indítása
Filename: "{app}\nssm.exe"; Parameters: "start ""{code:GetServiceName}"""; Flags: runhidden; StatusMsg: "Resource Monitor szolgáltatás indítása..."

[UninstallRun]
Filename: "{app}\nssm.exe"; Parameters: "stop ""{code:GetServiceName}"""; Flags: runhidden; RunOnceId: "StopResourceMonitor"
Filename: "{app}\nssm.exe"; Parameters: "remove ""{code:GetServiceName}"" confirm"; Flags: runhidden; RunOnceId: "RemoveResourceMonitor"

[Code]
var
  ServiceNamePage: TInputQueryWizardPage;
  PortPage: TInputQueryWizardPage;
  PythonExecutablePath: String;

procedure InitializeWizard;
begin
  ServiceNamePage := CreateInputQueryPage(wpWelcome,
    'Service Name', 'Enter the service name for Resource Monitor',
    'Please provide the name for the Windows Service (default is ResourceMonitor).');
  ServiceNamePage.Add('Service Name:', False);

  PortPage := CreateInputQueryPage(wpWelcome,
    'Resource Monitor Port', 'Enter the desired port for Resource Monitor',
    'Please provide the port on which the Resource Monitor service should run.');
  PortPage.Add('Desired Port (e.g. 5553):', False);
end;

function GetPythonPath: String;
var
  ResultCode: Integer;
  Lines: TArrayOfString;
begin
  Result := '';
  if Exec('cmd.exe', '/C where python > "' + ExpandConstant('{tmp}\python_path.txt') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if FileExists(ExpandConstant('{tmp}\python_path.txt')) then
    begin
      if LoadStringsFromFile(ExpandConstant('{tmp}\python_path.txt'), Lines) then
      begin
        if GetArrayLength(Lines) > 0 then
          Result := Trim(Lines[0]);
      end;
    end;
  end;
  if Result = '' then
    MsgBox('Python executable not found. Please ensure Python is installed and added to PATH.', mbError, MB_OK);
end;

function GetServiceName(Param: String): String;
begin
  if (ServiceNamePage.Values[0] = '') then
    Result := 'ResourceMonitor'
  else
    Result := ServiceNamePage.Values[0];
end;

function GetDefaultDirName(Param: string): string;
begin
  Result := 'C:\Apps\ResourceMonitor';
end;

function GetAppId(Param: string): string;
var
  svc: string;
  hash: Cardinal;
  i: Integer;
begin
  if (ServiceNamePage <> nil) and (Trim(ServiceNamePage.Values[0]) <> '') then
    svc := ServiceNamePage.Values[0]
  else
    svc := 'ResourceMonitor';
  hash := 0;
  for i := 1 to Length(svc) do
    hash := (hash * 31) + Ord(svc[i]);
  Result := Format('{RSRVM%8.8x-0000-0000-0000-000000000000}', [hash]);
end;

procedure ModifyMonitorFile(FilePath: string);
var
  Lines: TArrayOfString;
  I: Integer;
  NewPort: string;
begin
  NewPort := PortPage.Values[0];
  if NewPort = '' then NewPort := '5553';  // alapértelmezett port, ha nincs megadva
  if LoadStringsFromFile(FilePath, Lines) then begin
    for I := 0 to GetArrayLength(Lines) - 1 do begin
      if Pos('app.run(', Lines[I]) > 0 then begin
        Lines[I] := 'app.run(host=''0.0.0.0'', port=' + NewPort + ', debug=True)';
      end;
    end;
    SaveStringsToFile(FilePath, Lines, False);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    // Módosítja a monitor.py fájlt a felhasználó által megadott porttal
    ModifyMonitorFile(ExpandConstant('{app}\monitor.py'));

    // Lekéri a Python elérési utat
    PythonExecutablePath := GetPythonPath();
    if PythonExecutablePath = '' then
      Exit;

    // Ha nem létezik a virtuális környezet, létrehozza azt
    if not DirExists(ExpandConstant('{app}\venv')) then begin
      if Exec(PythonExecutablePath, '-m venv venv', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
        if ResultCode = 0 then begin
          // Telepíti a szükséges csomagokat: psutil és flask
          Exec(ExpandConstant('{app}\venv\Scripts\pip.exe'), 'install psutil flask', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
          if ResultCode <> 0 then
            MsgBox('Failed to install required Python packages.', mbError, MB_OK);
        end else
          MsgBox('Failed to create Python virtual environment. Please ensure Python installation is correct.', mbError, MB_OK);
      end;
    end;

    // Szolgáltatás telepítése
    if not Exec(ExpandConstant('{app}\nssm.exe'),
      'install "' + GetServiceName('') + '" "' + ExpandConstant('{app}\venv\Scripts\python.exe') + '" "' + ExpandConstant('{app}\resource_monitor.py') + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      MsgBox('Failed to install ResourceMonitor service.', mbError, MB_OK)
    else
    begin
      // Szolgáltatás indítása
      if not Exec(ExpandConstant('{app}\nssm.exe'), 'start "' + GetServiceName('') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        MsgBox('Failed to start ResourceMonitor service.', mbError, MB_OK);
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
end;
