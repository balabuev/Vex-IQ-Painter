unit MainFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Types, Math, Painter, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ActnList;

type
  TMainForm = class(TForm)
    Edit1: TEdit;
    Edit2: TEdit;
    Button3: TButton;
    Button4: TButton;
    ActionList1: TActionList;
    ConnectAction: TAction;
    DisconnectAction: TAction;
    SetupAction: TAction;
    PaintAction: TAction;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure ConnectActionUpdate(Sender: TObject);
    procedure DisconnectActionUpdate(Sender: TObject);
    procedure SetupActionUpdate(Sender: TObject);
    procedure PaintActionUpdate(Sender: TObject);
    procedure ConnectActionExecute(Sender: TObject);
    procedure DisconnectActionExecute(Sender: TObject);
    procedure SetupActionExecute(Sender: TObject);
    procedure PaintActionExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FRobot:    TRobot;
    FBuffer:   TBitmap;
    FImage:    TBitmap;
    FImageOff: TPoint;

    function  EnsureBuffer: TCanvas;
    procedure DrawBuffer;
    function  EnsureImage(const T: TTransform; K: TKinematics): TCanvas;
    procedure DrawImage(C: TCanvas);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.Button4Click(Sender: TObject);
begin
  FRobot.DisconnectAsync;
end;

procedure TMainForm.ConnectActionExecute(Sender: TObject);
begin
  FRobot.Connect;
end;

procedure TMainForm.ConnectActionUpdate(Sender: TObject);
begin
  ConnectAction.Enabled := (FRobot.State = rsDisconnected);
end;

procedure TMainForm.DisconnectActionExecute(Sender: TObject);
begin
  FRobot.DisconnectAsync;
end;

procedure TMainForm.DisconnectActionUpdate(Sender: TObject);
begin
  DisconnectAction.Enabled := (FRobot.State <> rsDisconnected);
end;

procedure TMainForm.DrawBuffer;
begin
  Canvas.Draw(0, 0, FBuffer);
end;

procedure TMainForm.DrawImage(C: TCanvas);
begin
  C.Draw(FImageOff.X, FImageOff.Y, FImage);
end;

function TMainForm.EnsureBuffer: TCanvas;
begin
  if FBuffer = nil then
    FBuffer := TBitmap.Create;
  if (FBuffer.Width <> ClientWidth) or
     (FBuffer.Height <> ClientHeight) then
    FBuffer.SetSize(ClientWidth, ClientHeight);
  Result := FBuffer.Canvas;
end;

function TMainForm.EnsureImage(const T: TTransform; K: TKinematics): TCanvas;
var
  wdt: Integer;
  hgh: Integer;
begin
  wdt := Abs(T.Transform(K.Field).Width);
  hgh := Abs(T.Transform(K.Field).Height);

  if FImage = nil then
  begin
    FImage             := TBitmap.Create;
    FImage.Transparent := True;
  end;
  if (FImage.Width <> wdt) or
     (FImage.Height <> hgh) then
  begin
    FImage.SetSize(wdt, hgh);
    FImage.Canvas.FillRect(Rect(0, 0, wdt, hgh));
  end;

  FImageOff := T.Transform(PointF(K.Field.Left, K.Field.Bottom));
  Result    := FImage.Canvas;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FRobot.DisconnectAsync;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FRobot := TRobot.Create;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FRobot.Free;
end;

procedure TMainForm.PaintActionExecute(Sender: TObject);
var
  drw: TProc<TKinematics>;
  org: TPoint;
  tns: TTransform;
  clr: Boolean;
begin
  org := Point(Width div 2, Height - Height div 5);
  tns := TTransform.Create(org, 2, -2);
  clr := True;

  drw := procedure(K: TKinematics)
  var
    bc: TCanvas;
    ic: TCanvas;
    p:  TPoint;
  begin
    bc := EnsureBuffer;
    ic := EnsureImage(tns, K);

    bc.Brush.Color := Color;
    bc.FillRect(ClientRect);

    if clr then
    begin
      ic.FillRect(Rect(0, 0, FImage.Width, FImage.Height));
      clr := False;
    end;
    p  := tns.Transform(K.Pen) - FImageOff;
    ic.Pixels[p.X, p.Y] := clBlack;

    DrawImage(bc);
    K.Draw(bc, tns);
    DrawBuffer;
  end;

  FRobot.Paint('D:\Projects\painter_vexiq\special\walle.svg', drw);
end;

procedure TMainForm.PaintActionUpdate(Sender: TObject);
begin
  PaintAction.Enabled := (FRobot.State = rsReady) and FRobot.IsSetup;
end;

procedure TMainForm.SetupActionExecute(Sender: TObject);
begin
  FRobot.Setup;
end;

procedure TMainForm.SetupActionUpdate(Sender: TObject);
begin
  SetupAction.Enabled := (FRobot.State = rsReady);
end;

end.
