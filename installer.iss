; -- installer.iss --
; Inno Setup script for ResourceMonitorInstaller

[Setup]
AppName=Resource Monitor
AppVersion=1.0
AppId={code:GetAppId}
DefaultDirName={code:GetDefaultDirName}
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
; Get Python executable path and save to temporary file
Filename: "cmd.exe"; Parameters: "/C where python > ""{tmp}\python_path.txt"""; Flags: runhidden
; Copy monitor.py to resource_monitor.py
Filename: "cmd.exe"; Parameters: "/C copy ""{app}\monitor.py"" ""{app}\resource_monitor.py"""; Flags: runhidden; StatusMsg: "Copying to resource_monitor.py file..."
; Convert resource_monitor.py encoding to UTF-8
Filename: "powershell.exe"; Parameters: "-Command ""Get-Content -Path '{app}\resource_monitor.py' | Set-Content -Path '{app}\resource_monitor.py' -Encoding UTF8"""; Flags: runhidden; StatusMsg: "Setting UTF-8 encoding for resource_monitor.py file..."
; Install service using resource_monitor.py
Filename: "{app}\nssm.exe"; Parameters: "install ""{code:GetServiceName}"" ""{app}\venv\Scripts\python.exe"" ""{app}\resource_monitor.py"""; WorkingDir: "{app}"; Flags: runhidden; StatusMsg: "Installing Resource Monitor service..."
; Start the service
Filename: "{app}\nssm.exe"; Parameters: "start ""{code:GetServiceName}"""; Flags: runhidden; StatusMsg: "Starting Resource Monitor service..."

[UninstallRun]
; Stop the service during uninstallation
Filename: "{app}\nssm.exe"; Parameters: "stop ""{code:GetServiceName}"""; Flags: runhidden; RunOnceId: "StopResourceMonitor"
; Remove the service during uninstallation
Filename: "{app}\nssm.exe"; Parameters: "remove ""{code:GetServiceName}"" confirm"; Flags: runhidden; RunOnceId: "RemoveResourceMonitor"

[Code]
var
  ServiceNamePage: TInputQueryWizardPage;  // Page for service name input
  PortPage: TInputQueryWizardPage;          // Page for port input
  PythonExecutablePath: String;              // Variable to store Python path

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
  Lines: TArrayOfString;  // Array to hold lines from the temporary file
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
  // Return user-defined service name or default value
  if (ServiceNamePage.Values[0] = '') then
    Result := 'ResourceMonitor'
  else
    Result := ServiceNamePage.Values[0];
end;

function GetDefaultDirName(Param: string): string;
begin
  // Default installation directory for the application
  Result := 'C:\Apps\ResourceMonitor';
end;

function GetAppId(Param: string): string;
var
  svc: string;
  hash: Cardinal;
  i: Integer;
begin
  // Generate a unique application ID based on service name
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
  Lines: TArrayOfString;  // Array to hold lines of the monitor file
  I: Integer;
  NewPort: string;        // Variable for new port value
begin
  NewPort := PortPage.Values[0];
  if NewPort = '' then NewPort := '5553';  // Default port if not specified
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
    // Modify the monitor.py file with the user-specified port
    ModifyMonitorFile(ExpandConstant('{app}\monitor.py'));

    // Retrieve the Python executable path
    PythonExecutablePath := GetPythonPath();
    if PythonExecutablePath = '' then
      Exit;

    // Create a virtual environment if it does not exist
    if not DirExists(ExpandConstant('{app}\venv')) then begin
      if Exec(PythonExecutablePath, '-m venv venv', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
        if ResultCode = 0 then begin
          // Install required packages: psutil and flask
          Exec(ExpandConstant('{app}\venv\Scripts\pip.exe'), 'install psutil flask', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
          if ResultCode <> 0 then
            MsgBox('Failed to install required Python packages.', mbError, MB_OK);
        end else
          MsgBox('Failed to create Python virtual environment. Please ensure Python installation is correct.', mbError, MB_OK);
      end;
    end;

    // Install the service
    if not Exec(ExpandConstant('{app}\nssm.exe'),
      'install "' + GetServiceName('') + '" "' + ExpandConstant('{app}\venv\Scripts\python.exe') + '" "' + ExpandConstant('{app}\resource_monitor.py') + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      MsgBox('Failed to install ResourceMonitor service.', mbError, MB_OK)
    else
    begin
      // Start the service after installation
      if not Exec(ExpandConstant('{app}\nssm.exe'), 'start "' + GetServiceName('') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        MsgBox('Failed to start ResourceMonitor service.', mbError, MB_OK);
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  // Initialization for the setup
  Result := True;
end;
