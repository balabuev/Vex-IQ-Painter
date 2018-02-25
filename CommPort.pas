unit CommPort;

interface

uses
  Windows, SysUtils, Classes, Registry, StrUtils;

type
  TPortInfo = record
    Port:        string;
    Description: string;
  end;

  TCommPort = class
  private
    FHandle:      HFILE;
    FIsConnected: Boolean;
    FPort:        string;
  public
    constructor Create;
    destructor  Destroy; override;

    function  ListPorts: TArray<TPortInfo>;
    function  SearchPort(const S: string; out P: TPortInfo): Boolean;
    procedure Connect(const APort: string);
    procedure Disconnect;
    procedure Read(var ABuffer; ASize: Integer; var ABytesRead: Integer);
    procedure ReadAllSkip;
    procedure Write(const AData; ASize: Integer); overload;
    procedure Write(B: Byte); overload;
    property  IsConnected: Boolean read FIsConnected;
    property  Port: string read FPort;
  end;

implementation

{ TCommPort }

procedure TCommPort.Connect(const APort: string);
var
  hfl: HFILE;
begin
  if not FIsConnected then
  begin
    hfl := CreateFile(PChar(APort), GENERIC_READ or GENERIC_WRITE, 0,
                      nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if hfl = INVALID_HANDLE_VALUE then
      RaiseLastOSError;

    if not PurgeComm(hfl, PURGE_RXABORT or PURGE_RXCLEAR or
                     PURGE_TXABORT or PURGE_TXCLEAR) then
      RaiseLastOSError;

    FHandle      := hfl;
    FIsConnected := True;
    FPort        := APort;
  end;
end;

constructor TCommPort.Create;
begin
  inherited Create;
end;

destructor TCommPort.Destroy;
begin
  Disconnect;
  inherited;
end;

procedure TCommPort.Disconnect;
begin
  if FIsConnected then
  begin
    CloseHandle(FHandle);
    FHandle      := 0;
    FIsConnected := False;
    FPort        := '';
  end;
end;

function TCommPort.ListPorts: TArray<TPortInfo>;
var
  reg: TRegistry;
  lst: TStringList;
  i:   Integer;

  function GetDescription(AKey: string; port: string): string;
  var
    reg:  TRegistry;
    lst:  TStringList;
    i:    Integer;
    ck:   string;
    rs:   string;
  begin
    reg := TRegistry.Create;
    lst := TStringList.Create;
    try
      reg.RootKey := HKEY_LOCAL_MACHINE;
      reg.OpenKeyReadOnly(AKey);
      reg.GetKeyNames(lst);
      reg.CloseKey;

      for i := 0 to lst.Count - 1 do
      begin
        ck := AKey + lst[i] + '\';
        if reg.OpenKeyReadOnly(ck + 'Device Parameters') then
        begin
          if reg.ReadString('PortName') = port then
          begin
            reg.CloseKey;
            reg.OpenKeyReadOnly(ck);
            rs := reg.ReadString('FriendlyName');
            Break;
          end;
        end
        else
        begin
          if reg.OpenKeyReadOnly(ck) and reg.HasSubKeys then
          begin
            rs := GetDescription(ck, port);
            if rs <> '' then
              Break; // for
          end;
        end;
      end;
      Result := rs;
    finally
      reg.Free;
      lst.Free;
    end;
  end;

begin
  lst := TStringList.Create;
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then
    begin
      reg.GetValueNames(lst);
      SetLength(Result, lst.Count);

      for i := 0 to lst.Count - 1 do
      begin
        Result[i].Port        := reg.ReadString(lst[i]);
        Result[i].Description := GetDescription('\System\CurrentControlSet' +
                                                '\Enum\', Result[i].Port);
      end;
    end;
  finally
    reg.Free;
    lst.Free;
  end;
end;

procedure TCommPort.Read(var ABuffer; ASize: Integer; var ABytesRead: Integer);
var
  p, eof: PByte;
  stt:    TComStat;
  brd:    DWORD;

  function InQueue: Integer;
  begin
    ClearCommError(FHandle, PCardinal(nil)^, @stt);
    Result := stt.cbInQue;
  end;

begin
  Assert(FIsConnected);
  p   := @ABuffer;
  eof := p + ASize;

  while True do
  begin
    brd := InQueue;
    if brd > DWORD(eof - p) then
      brd := DWORD(eof - p);

    if (brd > 0) and not ReadFile(FHandle, p^, brd, brd, nil) then
      RaiseLastOSError;

    if brd = 0 then
      Break; // while
    Inc(p, brd);
  end;

  ABytesRead := p - PByte(@ABuffer);
end;

procedure TCommPort.ReadAllSkip;
var
  buf: array[0..255] of Byte;
  rd:  Integer;
begin
  while True do
  begin
    Read(buf, SizeOf(buf), rd);
    if rd = 0 then
      Break; // while
  end;
end;

function TCommPort.SearchPort(const S: string; out P: TPortInfo): Boolean;
var
  pi: TPortInfo;
begin
  for pi in ListPorts do
    if ContainsText(pi.Description, S) then
    begin
      P := pi;
      Exit(True);
    end;
  Result := False;
end;

procedure TCommPort.Write(const AData; ASize: Integer);
var
  p, eof: PByte;
  bwr:    DWORD;
begin
  Assert(FIsConnected);
  p   := @AData;
  eof := p + ASize;

  while True do
  begin
    bwr := eof - p;
    if bwr = 0 then
      Break; // while

    if not WriteFile(FHandle, p^, bwr, bwr, nil) then
      RaiseLastOSError;

    Assert(bwr > 0);
    Inc(p, bwr);
  end;
end;

procedure TCommPort.Write(B: Byte);
begin
  Write(B, 1);
end;

end.
