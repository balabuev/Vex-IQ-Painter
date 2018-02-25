object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Painter'
  ClientHeight = 693
  ClientWidth = 932
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Edit1: TEdit
    Left = 8
    Top = 8
    Width = 121
    Height = 21
    TabOrder = 0
    Text = 'Edit1'
  end
  object Edit2: TEdit
    Left = 8
    Top = 35
    Width = 121
    Height = 21
    TabOrder = 1
    Text = 'Edit1'
  end
  object Button3: TButton
    Left = 8
    Top = 70
    Width = 75
    Height = 25
    Action = ConnectAction
    TabOrder = 2
  end
  object Button4: TButton
    Left = 8
    Top = 101
    Width = 75
    Height = 25
    Action = DisconnectAction
    TabOrder = 3
  end
  object Button1: TButton
    Left = 8
    Top = 144
    Width = 75
    Height = 25
    Action = SetupAction
    TabOrder = 4
  end
  object Button2: TButton
    Left = 8
    Top = 176
    Width = 75
    Height = 25
    Action = PaintAction
    TabOrder = 5
  end
  object ActionList1: TActionList
    Left = 168
    Top = 8
    object ConnectAction: TAction
      Caption = 'Connect'
      OnExecute = ConnectActionExecute
      OnUpdate = ConnectActionUpdate
    end
    object DisconnectAction: TAction
      Caption = 'Disconnect'
      OnExecute = DisconnectActionExecute
      OnUpdate = DisconnectActionUpdate
    end
    object SetupAction: TAction
      Caption = 'Setup'
      OnExecute = SetupActionExecute
      OnUpdate = SetupActionUpdate
    end
    object PaintAction: TAction
      Caption = 'Paint'
      OnExecute = PaintActionExecute
      OnUpdate = PaintActionUpdate
    end
  end
end
