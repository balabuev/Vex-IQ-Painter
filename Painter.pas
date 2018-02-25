unit Painter;

{$POINTERMATH ON}
{.$DEFINE NOCOMM}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Types, Math, XMLIntf, XMLDoc, Generics.Collections, GraphUtil,
  CommPort;

type
  EDrawerParseError = class(EXception);
  ERobotError       = class(EXception);

  PTransform = ^TTransform;
  TTransform = record
  private
    var
      FOffset: TPoint;
      FScaleX: Double;
      FScaleY: Double;

    class var
      FIdentity: TTransform;
  private
    class constructor Create;
  public
    constructor Create(AOffset: TPoint; AScaleX, AScaleY: Double); overload;
    constructor Create(AOffset: TPoint); overload;

    class property Identity: TTransform read FIdentity;
    function       Transform(const P: TPointF): TPoint; overload;
    function       Transform(const P: TRectF): TRect; overload;
    function       TransformBack(const P: TPoint): TPointF; overload;
    function       TransformBack(const P: TRect): TRectF; overload;

    property Offset: TPoint read FOffset write FOffset;
    property ScaleX: Double read FScaleX write FScaleX;
    property ScaleY: Double read FScaleY write FScaleY;
  end;

  TPointFHelper = record helper for TPointF
  public
    procedure Draw(C: TCanvas; const T: TTransform;
                   ARadius: Integer = 4);
  end;

  TRectFHelper = record helper for TRectF
  public
    procedure Draw(C: TCanvas; const T: TTransform);
    procedure Fill(C: TCanvas; const T: TTransform);
  end;

  TVector = record
  private
    FDX: Double;
    FDY: Double;

    function  GetAngle: Double;
    procedure SetAngle(const Value: Double);
    function  GetModule: Double;
    procedure SetModule(const Value: Double);
  public
    constructor Create(DX, DY: Double); overload;
    constructor Create(DX, DY, AModule: Double); overload;
    procedure   Draw(C: TCanvas; const P: TPointF; const T: TTransform);

    class operator Add(const P: TPointF; V: TVector): TPointF;
    class operator Add(const V1, V2: TVector): TVector;
    class operator Subtract(const P: TPointF; V: TVector): TPointF;
    class operator Subtract(const V1, V2: TVector): TVector;

    property Angle: Double read GetAngle write SetAngle;
    property Module: Double read GetModule write SetModule;
    property DX: Double read FDX write FDX;
    property DY: Double read FDY write FDY;
  end;

  TDrawer = class
  private
    type
      TItemKind = (ikMove, ikLine, ikCurve, ikSmoothCurve,
                   ikCurveData, ikEOf);

      PItem = ^TItem;
      TItem = record
        Kind: TItemKind;
        P:    TPointF;
      end;

      TRasterizer = reference to function(out P: TPointF): Boolean;
      TCurveGet   = reference to function(T: Double): TPointF;

    var
      FItems:         TArray<TItem>;
      FBounds:        TRectF;
      FScale:         Double;
      FCurrent:       PItem;
      FRasterizer:    TRasterizer;
      FRasterizeStep: Double;
      FPen:           TPointF;

    function  GetWidth: Double;
    function  GetHeight: Double;
    function  GetIsMove: Boolean;

    function  ExtractPaths(const ASvg: IXMLDocument): TArray<string>;
    procedure ParsePaths(const APaths: array of string);
    procedure ParsePath(const APath: string; AItems: TList<TItem>);
    procedure ParseMoveTo(var C: PChar; AItems: TList<TItem>);
    procedure ParseLineTo(var C: PChar; AItems: TList<TItem>);
    procedure ParseCurve(var C: PChar; AItems: TList<TItem>);
    procedure ParseSmoothCurve(var C: PChar; AItems: TList<TItem>);
    function  ParseCoordPair(var C: PChar): TPointF;
    function  IsNumber(var C: PChar): Boolean;
    function  ParseNumber(var C: PChar): Double;
    procedure ParseCommaWsp(var C: PChar);
    procedure SkipWhitespace(var C: PChar);
    procedure ParseError(C: PChar);
    procedure AddItem(AKind: TItemKind; const P: TPointF; AItems: TList<TItem>);

    function  TransformPoint(const AItem: PItem): TPointF;
    function  MaxBounds(const APoints: array of TPointF): Double;
    procedure InitRasterizer(ApproxLength: Double; const ACurveGet: TCurveGet);
    procedure InitLineRasterizer;
    procedure InitCurveRasterizer;
    procedure InitSmoothCurveRasterizer;
  public
    constructor Create(const APaths: array of string); overload;
    constructor Create(const ASvg: IXMLDocument); overload;
    constructor Create(const ASvgFile: string); overload;

    procedure Reset(AScale: Double = 1; ARasterizeStep: Double = 1);
    function  Step: Boolean;

    property Width: Double read GetWidth;
    property Height: Double read GetHeight;
    property Scale: Double read FScale;
    property RasterizeStep: Double read FRasterizeStep;
    property Pen: TPointF read FPen;
    property IsMove: Boolean read GetIsMove;
  end;

  TKinematics = class
  private
    const
      MM_LEN  = 76;
      L1_LEN  = 128;
      L2_LEN  = 165;
      R1_LEN  = 128;
      R2_LEN  = 177.7;
      PEN_LEN = 167.5;
      PEN_OFF = 10.5;
      FLD_Y   = 100;
      FLD_WDT = 130;
      FLD_HGH = 130;
    var
      FField:         TRectF;
      FML:            TPointF;
      FMR:            TPointF;
      FVL1:           TVector;
      FVL2:           TVector;
      FVR1:           TVector;
      FVPen:          TVector;
      FTarget:        TPointF;
      FTargetReached: Boolean;

    function  GetPen: TPointF;
    function  GetVR2: TVector;
    procedure SetTarget(const Value: TPointF);
    function  InitField: TRectF;
  public
    constructor Create;

    procedure Draw(C: TCanvas; const T: TTransform);
    procedure Step;

    property Field: TRectF read FField;
    property ML: TPointF read FML;
    property MR: TPointF read FMR;
    property VL1: TVector read FVL1;
    property VL2: TVector read FVL2;
    property VR1: TVector read FVR1;
    property VR2: TVector read GetVR2;
    property VPen: TVector read FVPen;
    property Pen: TPointF read GetPen;
    property Target: TPointF read FTarget write SetTarget;
    property TargetReached: Boolean read FTargetReached;
  end;

  TRobotState  = (rsDisconnected, rsReady, rsSetup, rsPaint);
  TRobotStates = set of TRobotState;

  TRobot = class
  private
    FState:   TRobotState;
    FIsSetup: Boolean;
    FAbort:   Boolean;
    FPort:    TCommPort;

    procedure CheckState(ARequired: TRobotStates);
    procedure SendCmd(const B: array of Byte);
    function  WaitForCmd: Boolean;
    procedure StartWork(AWork: TRobotState);
    procedure FinishWork;
    procedure DoDisconnect;
  public
    constructor Create;
    destructor  Destroy; override;

    procedure Connect;
    procedure DisconnectAsync;
    procedure Setup;
    procedure Paint(const AFileName: string; const ADraw: TProc<TKinematics>);
    property  State: TRobotState read FState;
    property  IsSetup: Boolean read FIsSetup;
  end;

function Vector(DX, DY: Double): TVector; overload;
function Vector(DX, DY, AModule: Double): TVector; overload;
function VectorA(Angle, AModule: Double): TVector; overload;

implementation

uses MainFormUnit;

function Vector(DX, DY: Double): TVector;
begin
  Result := TVector.Create(DX, DY);
end;

function Vector(DX, DY, AModule: Double): TVector;
begin
  Result := TVector.Create(DX, DY, AModule);
end;

function VectorA(Angle, AModule: Double): TVector;
begin
  Result       := TVector.Create(AModule, 0);
  Result.Angle := Angle;
end;

{ TVector }

class operator TVector.Add(const P: TPointF; V: TVector): TPointF;
begin
  Result := PointF(P.X + V.DX, P.Y + V.DY);
end;

class operator TVector.Add(const V1, V2: TVector): TVector;
begin
  Result := Vector(V1.DX + V2.DX, V1.DY + V2.DY);
end;

constructor TVector.Create(DX, DY, AModule: Double);
begin
  FDX    := DX;
  FDY    := DY;
  Module := AModule;
end;

constructor TVector.Create(DX, DY: Double);
begin
  FDX := DX;
  FDY := DY;
end;

procedure TVector.Draw(C: TCanvas; const P: TPointF; const T: TTransform);
var
  b, e: TPoint;
begin
  b  := T.Transform(P);
  e  := T.Transform(P + Self);

  C.MoveTo(b.X, b.Y);
  C.LineTo(e.X, e.Y);
end;

function TVector.GetAngle: Double;
var
  md: Double;
begin
  md := Module;
  if md = 0 then
    Exit(0);
  Result := ArcCos(FDX / md);
  if FDY < 0 then
    Result := 2 * Pi - Result;
end;

function TVector.GetModule: Double;
begin
  Result := Sqrt(FDX * FDX + FDY * FDY);
end;

procedure TVector.SetAngle(const Value: Double);
var
  md: Double;
begin
  md := Module;
  if md <> 0 then
  begin
    FDX := md * Cos(Value);
    FDY := md * Sin(Value);
  end;
end;

procedure TVector.SetModule(const Value: Double);
var
  md: Double;
  sc: Double;
begin
  md := Module;
  if md = 0 then
  begin
    FDX := Value;
    FDY := 0;
  end
  else if Value <> md then
  begin
    sc  := Value / md;
    FDX := FDX * sc;
    FDY := FDY * sc;
  end;
end;

class operator TVector.Subtract(const V1, V2: TVector): TVector;
begin
  Result := Vector(V1.DX - V2.DX, V1.DY - V2.DY);
end;

class operator TVector.Subtract(const P: TPointF; V: TVector): TPointF;
begin
  Result := PointF(P.X - V.DX, P.Y - V.DY);
end;

{ TTransform }

constructor TTransform.Create(AOffset: TPoint; AScaleX, AScaleY: Double);
begin
  FOffset := AOffset;
  FScaleX := AScaleX;
  FScaleY := AScaleY;
end;

constructor TTransform.Create(AOffset: TPoint);
begin
  FOffset := AOffset;
  FScaleX := 1.0;
  FScaleY := 1.0;
end;

function TTransform.Transform(const P: TPointF): TPoint;
begin
  Result := Point(Round(Offset.X + P.X * ScaleX),
                  Round(Offset.Y + P.Y * ScaleY));
end;

function TTransform.TransformBack(const P: TPoint): TPointF;
begin
  Result := PointF((P.X - Offset.X) / ScaleX,
                   (P.Y - Offset.Y) / ScaleY);
end;

class constructor TTransform.Create;
begin
  FIdentity := TTransform.Create(Point(0, 0), 1, 1);
end;

function TTransform.Transform(const P: TRectF): TRect;
begin
  Result.TopLeft     := Transform(P.TopLeft);
  Result.BottomRight := Transform(P.BottomRight);
end;

function TTransform.TransformBack(const P: TRect): TRectF;
begin
  Result.TopLeft     := TransformBack(P.TopLeft);
  Result.BottomRight := TransformBack(P.BottomRight);
end;

{ TPointFHelper }

procedure TPointFHelper.Draw(C: TCanvas;
  const T: TTransform; ARadius: Integer);
var
  d: TPoint;
begin
  d := T.Transform(Self);
  C.Ellipse(d.X - ARadius, d.Y - ARadius, d.X + ARadius, d.Y + ARadius);
end;

{ TKinematics }

procedure TKinematics.Step;
var
  off:  TPointF;
  jn:   TPointF;
  iter: Integer;
begin
  iter := 0;
  while not FTargetReached do
  begin
    { Right side }

    off   := Target - (MR + VR1);
    FVPen := Vector(off.X, off.Y, PEN_LEN);

    off   := Target - VPen - MR;
    FVR1  := Vector(off.X, off.Y, R1_LEN);

    jn    := MR + VR1 + VR2;

    { Left side }

    off   := jn - (ML + VL1);
    FVL2  := Vector(off.X, off.Y, L2_LEN);

    off   := jn - VL2 - ML;
    FVL1  := Vector(off.X, off.Y, L1_LEN);

    { Results }

    FTargetReached := (Pen.Distance(Target) < 0.1) and
                      ((ML + FVL1 + FVL2).Distance(jn) < 0.1);
    if iter > 100 then
      Break;
    Inc(iter);
  end;
end;

constructor TKinematics.Create;
begin
  inherited Create;

  FField  := InitField;
  FML     := PointF(-MM_LEN / 2, 0);
  FMR     := PointF(+MM_LEN / 2, 0);
  FVL1    := VectorA(Pi / 2 + Pi / 4, L1_LEN);
  FVL2    := VectorA(Pi / 2 - Pi / 4, L2_LEN);
  FVR1    := VectorA(Pi / 2 - Pi / 4, R1_LEN);
  FVPen   := VectorA(Pi / 2 + Pi / 4, PEN_LEN);
  FTarget := Pen;
end;

procedure TKinematics.Draw(C: TCanvas; const T: TTransform);
begin
  { Field }

  C.Pen.Width   := 1;
  C.Pen.Color   := GetShadowColor(clBtnFace, -20);
  C.Brush.Style := bsClear;

  FField.Draw(C, T);

  { Robot }

  C.Pen.Width := 2;

  C.Pen.Color := clBlack;
  ML.Draw(C, T);
  MR.Draw(C, T);

  C.Pen.Color := clGray;
  VL1.Draw(C, ML, T);
  VL2.Draw(C, ML + VL1, T);

  C.Pen.Color := clGray;
  VR1.Draw(C, MR, T);
  VR2.Draw(C, MR + VR1, T);
  VectorA(VPen.Angle + Pi / 2, PEN_OFF).Draw(C, Pen, T);

  if TargetReached then
    C.Pen.Color := clGreen
  else
    C.Pen.Color := clRed;
  Pen.Draw(C, T);
end;

function TKinematics.GetPen: TPointF;
begin
  Result := MR + VR1 + VPen;
end;

function TKinematics.GetVR2: TVector;
var
  off: TPointF;
begin
  off    := Pen + VectorA(VPen.Angle + Pi / 2, PEN_OFF) - (MR + VR1);
  Result := Vector(off.X, off.Y, R2_LEN);
end;

function TKinematics.InitField: TRectF;
begin
  Result := RectF(-FLD_WDT / 2, FLD_Y, FLD_WDT / 2, FLD_Y + FLD_HGH);
end;

procedure TKinematics.SetTarget(const Value: TPointF);
begin
  FTarget        := Value;
  FTargetReached := False;
end;

{ TDrawer }

constructor TDrawer.Create(const APaths: array of string);
begin
  inherited Create;
  ParsePaths(APaths);
  Reset;
end;

constructor TDrawer.Create(const ASvg: IXMLDocument);
begin
  Create(ExtractPaths(ASvg));
end;

procedure TDrawer.AddItem(AKind: TItemKind; const P: TPointF;
  AItems: TList<TItem>);
var
  itm: TItem;
begin
  itm.Kind := AKind;
  itm.P    := P;
  AITems.Add(itm);
end;

constructor TDrawer.Create(const ASvgFile: string);
begin
  Create(LoadXMLDocument(ASvgFile));
end;

procedure TDrawer.InitCurveRasterizer;
var
  p0, p1: TPointF;
  p2, p3: TPointF;
  apl:    Double;
begin
  p0  := FPen;
  p1  := TransformPoint(FCurrent);
  p2  := TransformPoint(FCurrent + 1);
  p3  := TransformPoint(FCurrent + 2);
  apl := MaxBounds([p0, p1, p2, p3]);

  InitRasterizer(apl, function(T: Double): TPointF
  var
    a, b, c, d: Double;
  begin
    a := (1 - T) * (1 - T) * (1 - T);
    b := 3 * T * (1 - T) * (1 - T);
    c := 3 * T * T * (1 - T);
    d := T * T * T;

    Result.X := a * p0.X + b * p1.X + c * p2.X + d * p3.X;
    Result.Y := a * p0.Y + b * p1.Y + c * p2.Y + d * p3.Y;
  end);
end;

procedure TDrawer.ParsePath(const APath: string; AItems: TList<TItem>);
var
  c: PChar;
begin
  c := @APath[1];
  SkipWhitespace(c);

  while True do
  begin
    case c^ of
      'M':  ParseMoveTo(c, AItems);
      'L':  ParseLineTo(c, AItems);
      'C':  ParseCurve(c, AItems);
      'S':  ParseSmoothCurve(c, AItems);
      #0:   Break; // while
    else
      ParseError(c);
    end;
    SkipWhitespace(c);
  end;
end;

procedure TDrawer.ParsePaths(const APaths: array of string);
var
  lst: TList<TItem>;
  i:   Integer;
  itm: PItem;
begin
  lst := TList<TItem>.Create;
  try
    for i := 0 to High(APaths) do
      ParsePath(APaths[i], lst);
    AddItem(ikEOf, PointF(0, 0), lst);

    FItems  := lst.ToArray;
    FBounds := RectF(MaxDouble, MaxDouble, -MaxDouble, -MaxDouble);

    itm := @FItems[0];
    while itm.Kind <> ikEOf do
    begin
      if FBounds.Left > itm.P.X then
        FBounds.Left := itm.P.X;
      if FBounds.Right < itm.P.X then
        FBounds.Right := itm.P.X;
      if FBounds.Top > itm.P.Y then
        FBounds.Top := itm.P.Y;
      if FBounds.Bottom < itm.P.Y then
        FBounds.Bottom := itm.P.Y;
      Inc(itm);
    end;
  finally
    lst.Free;
  end;
end;

procedure TDrawer.ParseSmoothCurve(var C: PChar; AItems: TList<TItem>);
var
  p: TPointF;
begin
  Assert(C^ = 'S');
  Inc(C);
  SkipWhitespace(C);

  while IsNumber(C) do
  begin
    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikCurve, p, AItems);

    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikCurveData, p, AItems);
  end;
end;

procedure TDrawer.Reset(AScale, ARasterizeStep: Double);
begin
  FCurrent       := @FItems[0];
  FRasterizer    := nil;
  FPen           := PointF(0, 0);
  FScale         := AScale;
  FRasterizeStep := ARasterizeStep;
end;

procedure TDrawer.ParseCommaWsp(var C: PChar);
begin
  SkipWhitespace(C);
  if C^ = ',' then
    Inc(C);
  SkipWhitespace(C);
end;

procedure TDrawer.SkipWhitespace(var C: PChar);
begin
  while (Ord(C^) > 0) and (Ord(C^) <= 32) do
    Inc(C);
end;

procedure TDrawer.InitSmoothCurveRasterizer;
begin
  raise ENotImplemented.Create('Not implemented');
end;

function TDrawer.Step: Boolean;
label
  L;
const
  OFFSET: array[TItemKind] of Integer = (
    1, // ikMove
    1, // ikLine
    3, // ikCurve
    2, // ikSmoothCurve
    0, // ikCurveData
    0  // ikEOf
  );
var
  p: TPointF;
begin
  if Assigned(FRasterizer) then
  begin
L:
    if FRasterizer(p) then
    begin
      FPen := p;
      Exit(True);
    end;
    FRasterizer := nil;
  end;

  case FCurrent.Kind of
    ikMove:         FPen := TransformPoint(FCurrent);
    ikLine:         InitLineRasterizer;
    ikCurve:        InitCurveRasterizer;
    ikSmoothCurve:  InitSmoothCurveRasterizer;
    ikEOf:          Exit(False);
  else
    Assert(False);
  end;
  Inc(FCurrent, OFFSET[FCurrent.Kind]); // Skip to next item.

  if Assigned(FRasterizer) then
    goto L;
  Result := True;
end;

function TDrawer.TransformPoint(const AItem: PItem): TPointF;
begin
  Result.X := (AItem.P.X - FBounds.Left) * FScale;
  Result.Y := (AItem.P.Y - FBounds.Top) * FScale;
end;

function TDrawer.ParseCoordPair(var C: PChar): TPointF;
begin
  Result.X := ParseNumber(C);
  ParseCommaWsp(C);
  Result.Y := ParseNumber(C);
end;

procedure TDrawer.ParseCurve(var C: PChar; AItems: TList<TItem>);
var
  p: TPointF;
begin
  Assert(C^ = 'C');
  Inc(C);
  SkipWhitespace(C);

  while IsNumber(C) do
  begin
    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikCurve, p, AItems);

    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikCurveData, p, AItems);

    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikCurveData, p, AItems);
  end;
end;

procedure TDrawer.ParseError(C: PChar);
var
  s: string;
begin
  s := C;
  if Length(s) > 16 then
    s := Copy(s, 1, 16) + '...';
  raise EDrawerParseError.CreateFmt('SVG path parse error: %s', [s]);
end;

procedure TDrawer.ParseLineTo(var C: PChar; AItems: TList<TItem>);
var
  p: TPointF;
begin
  Assert(C^ = 'L');
  Inc(C);
  SkipWhitespace(C);

  while IsNumber(C) do
  begin
    p := ParseCoordPair(C);
    ParseCommaWsp(C);
    AddItem(ikLine, p, AItems);
  end;
end;

procedure TDrawer.ParseMoveTo(var C: PChar; AItems: TList<TItem>);
var
  p:   TPointF;
  knd: TItemKind;
begin
  Assert(C^ = 'M');
  Inc(C);
  SkipWhitespace(C);

  knd := ikMove;
  while IsNumber(C) do
  begin
    p := ParseCoordPair(C);
    ParseCommaWsp(C);

    AddItem(knd, p, AItems);
    knd := ikLine;
  end;
end;

function TDrawer.ParseNumber(var C: PChar): Double;
var
  b:  PChar;
  s:  string;
  v:  Extended;
  cd: Integer;
begin
  b := C;
  if AnsiChar(C^) in ['-', '+'] then
    Inc(C);
  while AnsiChar(C^) in ['0'..'9'] do
    Inc(C);
  if C^ = '.' then
    Inc(C);
  while AnsiChar(C^) in ['0'..'9'] do
    Inc(C);
  if AnsiChar(C^) in ['E', 'e'] then
    Inc(C);
  if AnsiChar(C^) in ['-', '+'] then
    Inc(C);
  while AnsiChar(C^) in ['0'..'9'] do
    Inc(C);

  SetString(s, b, C - b);
  Val(s, v, cd);
  if cd <> 0 then
    ParseError(b);
  Result := v;
end;

function TDrawer.ExtractPaths(const ASvg: IXMLDocument): TArray<string>;

  procedure AddPath(const S: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := S;
  end;

  procedure Scan(ANode: IXMLNode);
  var
    pth: string;
    i:   Integer;
  begin
    if (ANode.NodeName = 'path') and ANode.HasAttribute('d') then
    begin
      pth := ANode.Attributes['d'];
      AddPath(pth);
    end;

    for i := 0 to ANode.ChildNodes.Count - 1 do
      Scan(ANode.ChildNodes[i]);
  end;

begin
  SetLength(Result, 0);
  Scan(ASvg.Node);
end;

function TDrawer.GetHeight: Double;
begin
  Result := FBounds.Height;
end;

function TDrawer.GetIsMove: Boolean;
begin
  Result := not Assigned(FRasterizer);
end;

function TDrawer.GetWidth: Double;
begin
  Result := FBounds.Width;
end;

function TDrawer.IsNumber(var C: PChar): Boolean;
begin
  Result := AnsiChar(C^) in ['0'..'9', '+', '-', '.'];
end;

function TDrawer.MaxBounds(const APoints: array of TPointF): Double;
var
  i:  Integer;
  bs: TRectF;
begin
  bs := RectF(MaxDouble, MaxDouble, -MaxDouble, -MaxDouble);

  for i := 0 to High(APoints) do
  begin
    if bs.Left > APoints[i].X then
      bs.Left := APoints[i].X;
    if bs.Right < APoints[i].X then
      bs.Right := APoints[i].X;
    if bs.Top > APoints[i].Y then
      bs.Top := APoints[i].Y;
    if bs.Bottom < APoints[i].Y then
      bs.Bottom := APoints[i].Y;
  end;

  Result := Max(bs.Width, bs.Height);
end;

procedure TDrawer.InitLineRasterizer;
var
  p0, p1: TPointF;
  apl:    Double;
begin
  p0  := FPen;
  p1  := TransformPoint(FCurrent);
  apl := MaxBounds([p0, p1]);

  InitRasterizer(apl, function(T: Double): TPointF
  begin
    Result.X := (1 - T) * p0.X + T * p1.X;
    Result.Y := (1 - T) * p0.Y + T * p1.Y;
  end);
end;

procedure TDrawer.InitRasterizer(ApproxLength: Double;
  const ACurveGet: TCurveGet);
var
  cg:    TCurveGet;
  t, dt: Double;
  prev:  TPointF;
  aln:   Double;
begin
  cg   := ACurveGet;
  t    := -1; // Before first step mark.
  aln  := ApproxLength;

  if aln > 0 then
    dt := (0.2 / aln) * RasterizeStep
  else
    dt := 1;

  FRasterizer := function(out P: TPointF): Boolean
  label
    L;
  var
    oldt: Double;
    tmin: Double;
    tmax: Double;
    cur:  TPointF;
    dst:  Double;
  begin
    if t < 0 then      // First step.
    begin
      t   := 0;
      cur := cg(t);
      goto L;
    end
    else if t = 1 then // EOf step.
      Exit(False);

    oldt := t;
    tmin := t;
    tmax := 0;

    while True do
    begin
      if tmax = 0 then
        t := t + dt
      else
        t := (tmin + tmax) / 2;
      if t > 1 then
        t := 1;

      cur := cg(t);
      dst := cur.Distance(prev);

      if tmax = 0 then
      begin
        if dst >= RasterizeStep then
          tmax := t
        else if t < 1 then
          tmin := t
        else
          Break; // Done.
      end
      else
      begin
        if dst > RasterizeStep * 1.1 then
          tmax := t
        else if dst < RasterizeStep * 0.9 then
          tmin := t
        else
          Break; // Done.
      end;
    end;

    dt := t - oldt;
  L:
    prev   := cur;
    P      := cur;
    Result := True;
  end;
end;

{ TRectFHelper }

procedure TRectFHelper.Draw(C: TCanvas; const T: TTransform);
var
  d: TRect;
begin
  d := T.Transform(Self);
  C.Rectangle(d);
end;

procedure TRectFHelper.Fill(C: TCanvas; const T: TTransform);
var
  d: TRect;
begin
  d := T.Transform(Self);
  C.FillRect(d);
end;

{ TRobot }

procedure TRobot.StartWork(AWork: TRobotState);
begin
  CheckState([rsReady]);
  FState := AWork;
  FAbort := False;
end;

procedure TRobot.FinishWork;
begin
  if FAbort then
    DoDisconnect
  else
    FState := rsReady;
end;

procedure TRobot.CheckState(ARequired: TRobotStates);
begin
  if not (FState in ARequired) then
    raise ERobotError.Create('Invalid robot state');
end;

procedure TRobot.Connect;
{$IFNDEF NOCOMM}
var
  nfo: TPortInfo;
{$ENDIF}
begin
  CheckState([rsDisconnected]);

  {$IFNDEF NOCOMM}
  if not FPort.SearchPort('VEX', nfo) then
    raise ERobotError.Create('No connected VEX IQ found');
  FPort.Connect(nfo.Port);
  {$ENDIF}

  FState   := rsReady;
  FIsSetup := False;
end;

constructor TRobot.Create;
begin
  inherited;
  FPort  := TCommPort.Create;
  FState := rsDisconnected;
end;

destructor TRobot.Destroy;
begin
  FPort.Free;
  inherited;
end;

procedure TRobot.DisconnectAsync;
begin
  if FState = rsReady then
    DoDisconnect
  else
    FAbort := True;
end;

procedure TRobot.DoDisconnect;
begin
  {$IFNDEF NOCOMM}
  FPort.Disconnect;
  {$ENDIF}
  FState := rsDisconnected;
end;

var
  dold: Integer;
  dsum: Double;
  dcnt: Integer;

procedure TRobot.Paint(const AFileName: string;
  const ADraw: TProc<TKinematics>);
const
  CMD: array[Boolean] of Byte = (2, 3);
var
  drw:    TDrawer;
  kns:    TKinematics;
  scl:    Double;
  off:    TPointF;
  L, R:   Double;
  dl, dr: Integer;
begin
  StartWork(rsPaint);
  drw := TDrawer.Create(AFileName);
  kns := TKinematics.Create;
  try
    scl := -Min(kns.Field.Width / drw.Width,
                kns.Field.Height / drw.Height);
    off := PointF(kns.Field.Right, kns.Field.Bottom);

    drw.Reset(scl, 1 * Abs(scl) * 3); //!!!

    while drw.Step do
    begin
      kns.Target := drw.Pen + off;
      kns.Step;

      L := 180 - kns.VL1.Angle / (2 * Pi) * 360; // Angles in degrees.
      R := kns.VR1.Angle / (2 * Pi) * 360;       //
      if L > 180 then                            //
        L := L - 360;                            //
      if R > 180 then                            //
        R := R - 360;                            //

      if (L < - 100) or (L > 100) or
         (R < - 100) or (R > 100) then
        Assert(False);

      dl := Round(L * 5 * 3) + 10000; // Apply gear ratio (60 / 12 = 5),
      dr := Round(R * 5 * 3) + 10000; // and offset, which prevents
                                      // negative data values.

      dsum := dsum + Abs(dl - dold);
      dcnt := dcnt + 1;
      dold := dl;

      MainForm.Edit1.Text := FloatToStr(dsum / dcnt);
//      MainForm.Edit2.Text := FloatToStr(dr);

      SendCmd([CMD[drw.IsMove], dl and $FF, dl shr 8,
                                dr and $FF, dr shr 8]);
      if not WaitForCmd then
        Exit;

      if Assigned(ADraw) then
        ADraw(kns);
    end;

    SendCmd([4]); // Drawing finished.
    WaitForCmd;
  finally
    drw.Free;
    kns.Free;
    FinishWork;
  end;
end;

procedure TRobot.SendCmd(const B: array of Byte);
const
  PREFIX: array[0..4] of Byte = ($c9, $36, $b8, $47, $7a);
var
  dt:  array of Byte;
  idx: Integer;
  i:   Integer;
begin
  SetLength(dt, Length(PREFIX) + 1 + Length(B));

  idx := Length(PREFIX);
  Move(PREFIX, dt[0], idx);

  dt[idx] := Length(B);
  Inc(idx);

  for i := 0 to High(B) do
  begin
    dt[idx] := B[i];
    Inc(idx);
  end;

  {$IFNDEF NOCOMM}
  FPort.Write(dt[0], Length(dt));
  {$ENDIF}
end;

procedure TRobot.Setup;
begin
  StartWork(rsSetup);
  try
    SendCmd([1]); // Setup.
    if not WaitForCmd then
      Exit;
    FIsSetup := True;
  finally
    FinishWork;
  end;
end;

function TRobot.WaitForCmd: Boolean;
const
  FLAG = #$0A'VP_'#$01#$0A;
{$IFNDEF NOCOMM}
var
  dt, s: string;
  buf:   array[0..255] of Byte;
  rd:    Integer;
  i: Integer;
{$ENDIF}
begin
  {$IFNDEF NOCOMM}
  dt := '';
  {$ENDIF}

  while not FAbort do
  begin
    Application.ProcessMessages;

    {$IFNDEF NOCOMM}
    FPort.Read(buf, SizeOf(buf), rd);
    if rd > 0 then
    begin
      SetLength(s, rd);
      for i := 0 to rd - 1 do
        s[i + 1] := Char(buf[i]);
      dt := dt + s;

      if Pos(FLAG, dt) > 0 then
        Exit(True);
    end;
    {$ELSE}
    Exit(True);
    {$ENDIF}
  end;

  Result := False;
end;

end.
