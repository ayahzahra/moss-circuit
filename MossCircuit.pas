program MossCircuit;

{$mode objfpc}{$H+}
{$apptype gui}

uses
  Windows, Messages, SysUtils, Math, Types;

const
  WindowClassName = 'MossCircuitWindow';
  WindowTitle = 'Moss Circuit - Kebun Mini';
  BoardCells = 24;
  MaxSegments = BoardCells * BoardCells;
  TimerId = 1;
  StartSpeed = 145;
  MinimumSpeed = 66;

type
  TGameState = (gsReady, gsPlaying, gsPaused, gsOver, gsComplete);
  TCell = record
    X, Y: Integer;
  end;
  TSnake = array[0..MaxSegments - 1] of TCell;

var
  MainWindow: HWND = 0;
  Snake: TSnake;
  FoodCell: TCell;
  SnakeLength, Score, BestScore: Integer;
  DirectionX, DirectionY, NextDirectionX, NextDirectionY: Integer;
  TurnQueued, LightTheme: Boolean;
  State: TGameState;
  BoardLeft, BoardTop, BoardSize, CellSize: Integer;
  ActionButton: TRect;
  DataDirectory: string;

function RGBColor(R, G, B: Byte): COLORREF;
begin
  Result := R or (G shl 8) or (B shl 16);
end;

function ThemeColor(DarkR, DarkG, DarkB, LightR, LightG, LightB: Byte): COLORREF;
begin
  if LightTheme then
    Result := RGBColor(LightR, LightG, LightB)
  else
    Result := RGBColor(DarkR, DarkG, DarkB);
end;

function PageColor: COLORREF;
begin
  Result := ThemeColor(17, 23, 17, 241, 239, 229);
end;

function PanelColor: COLORREF;
begin
  Result := ThemeColor(30, 40, 29, 251, 250, 244);
end;

function BorderColor: COLORREF;
begin
  Result := ThemeColor(57, 73, 52, 215, 213, 196);
end;

function TextColor: COLORREF;
begin
  Result := ThemeColor(240, 241, 219, 38, 45, 32);
end;

function MutedColor: COLORREF;
begin
  Result := ThemeColor(162, 173, 152, 115, 119, 102);
end;

function AccentColor: COLORREF;
begin
  Result := ThemeColor(213, 242, 122, 84, 122, 56);
end;

function SnakeColor: COLORREF;
begin
  Result := ThemeColor(135, 199, 111, 102, 151, 72);
end;

function FoodColor: COLORREF;
begin
  Result := ThemeColor(255, 136, 118, 207, 89, 72);
end;

function CanvasColor: COLORREF;
begin
  Result := ThemeColor(17, 26, 21, 243, 243, 232);
end;

function GridColor: COLORREF;
begin
  Result := ThemeColor(37, 51, 40, 222, 224, 208);
end;

function DataFile(const FileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(DataDirectory) + FileName;
end;

procedure LoadSettings;
var
  FileHandle: TextFile;
  Value: string;
  Parsed: Integer;
begin
  DataDirectory := GetEnvironmentVariable('APPDATA');
  if DataDirectory = '' then
    DataDirectory := ExtractFilePath(ParamStr(0));
  DataDirectory := IncludeTrailingPathDelimiter(DataDirectory) + 'MossCircuit';
  ForceDirectories(DataDirectory);

  LightTheme := False;
  if FileExists(DataFile('theme.dat')) then
  begin
    AssignFile(FileHandle, DataFile('theme.dat'));
    {$I-}
    Reset(FileHandle);
    if IOResult = 0 then
    begin
      ReadLn(FileHandle, Value);
      CloseFile(FileHandle);
      if IOResult = 0 then
        LightTheme := Value = 'light';
    end;
    {$I+}
  end;

  BestScore := 0;
  if FileExists(DataFile('best.dat')) then
  begin
    AssignFile(FileHandle, DataFile('best.dat'));
    {$I-}
    Reset(FileHandle);
    if IOResult = 0 then
    begin
      ReadLn(FileHandle, Value);
      CloseFile(FileHandle);
      if IOResult = 0 then
        if TryStrToInt(Value, Parsed) then
          BestScore := Max(0, Parsed);
    end;
    {$I+}
  end;
end;

procedure SaveSetting(const FileName, Value: string);
var
  FileHandle: TextFile;
begin
  AssignFile(FileHandle, DataFile(FileName));
  {$I-}
  Rewrite(FileHandle);
  if IOResult = 0 then
  begin
    WriteLn(FileHandle, Value);
    CloseFile(FileHandle);
    IOResult;
  end;
  {$I+}
end;

procedure DrawTextRect(DC: HDC; const Bounds: TRect; const Value: string;
  Color: COLORREF; Size: Integer; Bold: Boolean; Flags: UINT);
var
  FontHandle, PreviousFont: HFONT;
  TextBounds: TRect;
begin
  FontHandle := CreateFont(-Size, 0, 0, 0,
    IfThen(Bold, FW_SEMIBOLD, FW_NORMAL), 0, 0, 0, DEFAULT_CHARSET,
    OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5,
    DEFAULT_PITCH or FF_DONTCARE, 'Segoe UI');
  PreviousFont := SelectObject(DC, FontHandle);
  SetBkMode(DC, TRANSPARENT);
  SetTextColor(DC, Color);
  TextBounds := Bounds;
  Windows.DrawText(DC, PChar(Value), Length(Value), TextBounds, Flags);
  SelectObject(DC, PreviousFont);
  DeleteObject(FontHandle);
end;

procedure FillRounded(DC: HDC; const Bounds: TRect; FillColor,
  LineColor: COLORREF; Radius: Integer);
var
  BrushHandle: HBRUSH;
  PenHandle: HPEN;
  PreviousBrush: HGDIOBJ;
  PreviousPen: HGDIOBJ;
begin
  BrushHandle := CreateSolidBrush(FillColor);
  PenHandle := CreatePen(PS_SOLID, 1, LineColor);
  PreviousBrush := SelectObject(DC, BrushHandle);
  PreviousPen := SelectObject(DC, PenHandle);
  RoundRect(DC, Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom,
    Radius, Radius);
  SelectObject(DC, PreviousBrush);
  SelectObject(DC, PreviousPen);
  DeleteObject(BrushHandle);
  DeleteObject(PenHandle);
end;

procedure FillCircle(DC: HDC; CenterX, CenterY, Radius: Integer;
  FillColor: COLORREF);
var
  BrushHandle, PreviousBrush: HBRUSH;
  PenHandle, PreviousPen: HPEN;
begin
  BrushHandle := CreateSolidBrush(FillColor);
  PenHandle := CreatePen(PS_SOLID, 1, FillColor);
  PreviousBrush := SelectObject(DC, BrushHandle);
  PreviousPen := SelectObject(DC, PenHandle);
  Ellipse(DC, CenterX - Radius, CenterY - Radius,
    CenterX + Radius + 1, CenterY + Radius + 1);
  SelectObject(DC, PreviousBrush);
  SelectObject(DC, PreviousPen);
  DeleteObject(BrushHandle);
  DeleteObject(PenHandle);
end;

procedure DrawPetal(DC: HDC; CenterX, CenterY, RadiusX, RadiusY: Integer;
  Color: COLORREF);
var
  BrushHandle, PreviousBrush: HBRUSH;
  PenHandle, PreviousPen: HPEN;
begin
  BrushHandle := CreateSolidBrush(Color);
  PenHandle := CreatePen(PS_SOLID, 1, Color);
  PreviousBrush := SelectObject(DC, BrushHandle);
  PreviousPen := SelectObject(DC, PenHandle);
  Ellipse(DC, CenterX - RadiusX, CenterY - RadiusY,
    CenterX + RadiusX + 1, CenterY + RadiusY + 1);
  SelectObject(DC, PreviousBrush);
  SelectObject(DC, PreviousPen);
  DeleteObject(BrushHandle);
  DeleteObject(PenHandle);
end;

procedure CalculateBoard(ClientWidth, ClientHeight: Integer);
var
  Padding: Integer;
begin
  Padding := 48;
  BoardSize := Min(ClientWidth - Padding * 2, ClientHeight - 286);
  BoardSize := Max(240, BoardSize);
  BoardLeft := (ClientWidth - BoardSize) div 2;
  BoardTop := 190;
  CellSize := BoardSize div BoardCells;
  BoardSize := CellSize * BoardCells;
  BoardLeft := (ClientWidth - BoardSize) div 2;
end;

procedure DrawHeader(DC: HDC; ClientWidth: Integer);
var
  BrandBox, TagBox: TRect;
  BrushHandle, OldBrush: HBRUSH;
  PenHandle, OldPen: HPEN;
begin
  BrandBox := Rect(36, 29, 82, 75);
  FillRounded(DC, BrandBox, PanelColor, BorderColor, 17);

  PenHandle := CreatePen(PS_SOLID, 2, AccentColor);
  OldPen := SelectObject(DC, PenHandle);
  BrushHandle := GetStockObject(NULL_BRUSH);
  OldBrush := SelectObject(DC, BrushHandle);
  MoveToEx(DC, 59, 66, nil);
  LineTo(DC, 59, 46);
  SelectObject(DC, OldBrush);
  SelectObject(DC, OldPen);
  DeleteObject(PenHandle);
  DrawPetal(DC, 53, 48, 5, 3, AccentColor);
  DrawPetal(DC, 65, 43, 5, 3, AccentColor);

  DrawTextRect(DC, Rect(96, 27, ClientWidth - 270, 58),
    'Moss Circuit', TextColor, 25, True, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  DrawTextRect(DC, Rect(98, 57, ClientWidth - 270, 79),
    'A tiny garden arcade  -  No. 01', MutedColor, 13, False,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE);

  TagBox := Rect(ClientWidth - 203, 38, ClientWidth - 37, 67);
  FillRounded(DC, TagBox, PanelColor, BorderColor, 15);
  FillCircle(DC, TagBox.Left + 17, 52, 3, AccentColor);
  DrawTextRect(DC, Rect(TagBox.Left + 29, TagBox.Top, TagBox.Right - 7,
    TagBox.Bottom), 'GARDEN ARCADE', MutedColor, 10, True,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

procedure DrawStats(DC: HDC; ClientWidth: Integer);
var
  ScoreBox, BestBox: TRect;
  StatValue: string;
begin
  ScoreBox := Rect(36, 94, (ClientWidth div 2) - 5, 154);
  BestBox := Rect((ClientWidth div 2) + 5, 94, ClientWidth - 36, 154);
  FillRounded(DC, ScoreBox, PanelColor, BorderColor, 13);
  FillRounded(DC, BestBox, PanelColor, BorderColor, 13);

  DrawTextRect(DC, Rect(ScoreBox.Left + 17, ScoreBox.Top, ScoreBox.Right - 8,
    ScoreBox.Bottom), 'Seeds gathered', MutedColor, 13, False,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  StatValue := Format('%.2d', [Score]);
  DrawTextRect(DC, Rect(ScoreBox.Left + 100, ScoreBox.Top, ScoreBox.Right - 17,
    ScoreBox.Bottom), StatValue, AccentColor, 23, True,
    DT_RIGHT or DT_VCENTER or DT_SINGLELINE);

  DrawTextRect(DC, Rect(BestBox.Left + 17, BestBox.Top, BestBox.Right - 8,
    BestBox.Bottom), 'Personal best', MutedColor, 13, False,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  StatValue := Format('%.2d', [BestScore]);
  DrawTextRect(DC, Rect(BestBox.Left + 100, BestBox.Top, BestBox.Right - 17,
    BestBox.Bottom), StatValue, TextColor, 23, True,
    DT_RIGHT or DT_VCENTER or DT_SINGLELINE);
end;

procedure DrawSnake(DC: HDC);
var
  I, CenterX, CenterY, Radius: Integer;
  PenHandle, PreviousPen: HPEN;
begin
  if SnakeLength <= 0 then
    Exit;
  Radius := Max(5, CellSize * 34 div 100);

  if SnakeLength > 1 then
  begin
    PenHandle := CreatePen(PS_SOLID, Radius * 2, SnakeColor);
    PreviousPen := SelectObject(DC, PenHandle);
    MoveToEx(DC, BoardLeft + Snake[SnakeLength - 1].X * CellSize + CellSize div 2,
      BoardTop + Snake[SnakeLength - 1].Y * CellSize + CellSize div 2, nil);
    for I := SnakeLength - 2 downto 0 do
      LineTo(DC, BoardLeft + Snake[I].X * CellSize + CellSize div 2,
        BoardTop + Snake[I].Y * CellSize + CellSize div 2);
    SelectObject(DC, PreviousPen);
    DeleteObject(PenHandle);
  end;

  for I := SnakeLength - 1 downto 1 do
  begin
    CenterX := BoardLeft + Snake[I].X * CellSize + CellSize div 2;
    CenterY := BoardTop + Snake[I].Y * CellSize + CellSize div 2;
    FillCircle(DC, CenterX, CenterY, Radius, SnakeColor);
  end;

  CenterX := BoardLeft + Snake[0].X * CellSize + CellSize div 2;
  CenterY := BoardTop + Snake[0].Y * CellSize + CellSize div 2;
  FillCircle(DC, CenterX, CenterY, Radius + 1, AccentColor);

  if DirectionX <> 0 then
  begin
    FillCircle(DC, CenterX + DirectionX * Radius div 3,
      CenterY - Radius div 2, Max(2, Radius div 6), PageColor);
    FillCircle(DC, CenterX + DirectionX * Radius div 3,
      CenterY + Radius div 2, Max(2, Radius div 6), PageColor);
  end
  else
  begin
    FillCircle(DC, CenterX - Radius div 2,
      CenterY + DirectionY * Radius div 3, Max(2, Radius div 6), PageColor);
    FillCircle(DC, CenterX + Radius div 2,
      CenterY + DirectionY * Radius div 3, Max(2, Radius div 6), PageColor);
  end;
end;

procedure DrawFlower(DC: HDC);
var
  I, CenterX, CenterY, PetalX, PetalY, PetalRadius: Integer;
  Angle: Double;
  LeafColor: COLORREF;
begin
  CenterX := BoardLeft + FoodCell.X * CellSize + CellSize div 2;
  CenterY := BoardTop + FoodCell.Y * CellSize + CellSize div 2;
  PetalRadius := Max(3, CellSize * 16 div 100);
  for I := 0 to 4 do
  begin
    Angle := I * 2 * Pi / 5;
    PetalX := CenterX + Round(Cos(Angle) * PetalRadius * 0.72);
    PetalY := CenterY + Round(Sin(Angle) * PetalRadius * 0.72);
    DrawPetal(DC, PetalX, PetalY, Max(3, CellSize div 8),
      Max(4, CellSize div 5), FoodColor);
  end;
  FillCircle(DC, CenterX, CenterY, Max(3, CellSize div 8),
    ThemeColor(255, 240, 189, 255, 243, 201));
  LeafColor := ThemeColor(168, 202, 128, 102, 140, 70);
  DrawPetal(DC, CenterX + CellSize div 4, CenterY - CellSize div 3,
    Max(3, CellSize div 6), Max(2, CellSize div 10), LeafColor);
end;

procedure DrawOverlay(DC: HDC; ClientWidth: Integer);
var
  Panel, Heading, Description: TRect;
  OverlayBrush: HBRUSH;
  Title, CopyText, ButtonText: string;
  ButtonWidth, ButtonTop: Integer;
begin
  case State of
    gsReady:
      begin
        Title := 'The garden is yours';
        CopyText := 'Gather moon-seeds. Follow the winding path, not the edge.';
        ButtonText := 'Tend the garden';
      end;
    gsPaused:
      begin
        Title := 'Garden at rest';
        CopyText := 'Take a breath. Your little winding path will wait.';
        ButtonText := 'Resume';
      end;
    gsOver:
      begin
        Title := 'The path loops back';
        if Score = 1 then
          CopyText := 'You gathered 1 seed. Shall we grow another?'
        else
          CopyText := Format('You gathered %d seeds. Shall we grow another?',
            [Score]);
        ButtonText := 'Grow again';
      end;
    gsComplete:
      begin
        Title := 'The garden is complete!';
        CopyText := 'You filled every corner with a winding trail. Amazing work!';
        ButtonText := 'Grow again';
      end;
    else
      Exit;
  end;

  Panel := Rect(BoardLeft, BoardTop, BoardLeft + BoardSize, BoardTop + BoardSize);
  OverlayBrush := CreateSolidBrush(CanvasColor);
  FillRect(DC, Panel, OverlayBrush);
  DeleteObject(OverlayBrush);

  Heading := Rect(Panel.Left + 24, Panel.Top + BoardSize div 2 - 76,
    Panel.Right - 24, Panel.Top + BoardSize div 2 - 38);
  Description := Rect(Panel.Left + 35, Heading.Bottom + 5, Panel.Right - 35,
    Heading.Bottom + 47);
  DrawTextRect(DC, Heading, Title, TextColor, 30, True,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  DrawTextRect(DC, Description, CopyText, MutedColor, 14, False,
    DT_CENTER or DT_VCENTER or DT_WORDBREAK);

  ButtonWidth := Max(150, Length(ButtonText) * 9 + 42);
  ButtonTop := Description.Bottom + 8;
  ActionButton := Rect((ClientWidth - ButtonWidth) div 2, ButtonTop,
    (ClientWidth + ButtonWidth) div 2, ButtonTop + 45);
  FillRounded(DC, ActionButton, AccentColor, AccentColor, 12);
  DrawTextRect(DC, ActionButton, ButtonText,
    ThemeColor(31, 42, 20, 250, 249, 239), 15, True,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

procedure DrawFooter(DC: HDC; ClientWidth, ClientHeight: Integer);
var
  Footer: TRect;
begin
  Footer := Rect(38, ClientHeight - 43, ClientWidth - 38, ClientHeight - 17);
  DrawTextRect(DC, Footer,
    'ARROW KEYS / WASD  steer     SPACE  pause     T  theme     R  restart',
    MutedColor, 11, False, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

procedure DrawScene(DC: HDC; ClientWidth, ClientHeight: Integer);
var
  OuterBoard, InnerBoard: TRect;
  BrushHandle: HBRUSH;
  I, X, Y: Integer;
  GridPen, PreviousPen: HPEN;
  PreviousBrush: HGDIOBJ;
begin
  CalculateBoard(ClientWidth, ClientHeight);
  SetBkMode(DC, TRANSPARENT);
  BrushHandle := CreateSolidBrush(PageColor);
  OuterBoard := Rect(BoardLeft - 10, BoardTop - 10,
    BoardLeft + BoardSize + 10, BoardTop + BoardSize + 10);
  FillRect(DC, Rect(0, 0, ClientWidth, ClientHeight), BrushHandle);
  DeleteObject(BrushHandle);

  DrawHeader(DC, ClientWidth);
  DrawStats(DC, ClientWidth);

  FillRounded(DC, OuterBoard, PanelColor, BorderColor, 21);
  InnerBoard := Rect(BoardLeft, BoardTop, BoardLeft + BoardSize,
    BoardTop + BoardSize);
  BrushHandle := CreateSolidBrush(CanvasColor);
  PreviousBrush := SelectObject(DC, BrushHandle);
  GridPen := CreatePen(PS_SOLID, 1, GridColor);
  PreviousPen := SelectObject(DC, GridPen);
  Rectangle(DC, InnerBoard.Left, InnerBoard.Top, InnerBoard.Right,
    InnerBoard.Bottom);
  for I := 1 to BoardCells - 1 do
  begin
    X := BoardLeft + I * CellSize;
    MoveToEx(DC, X, BoardTop, nil);
    LineTo(DC, X, BoardTop + BoardSize);
    Y := BoardTop + I * CellSize;
    MoveToEx(DC, BoardLeft, Y, nil);
    LineTo(DC, BoardLeft + BoardSize, Y);
  end;
  SelectObject(DC, PreviousPen);
  SelectObject(DC, PreviousBrush);
  DeleteObject(GridPen);
  DeleteObject(BrushHandle);

  DrawFlower(DC);
  DrawSnake(DC);
  if State <> gsPlaying then
    DrawOverlay(DC, ClientWidth);
  DrawFooter(DC, ClientWidth, ClientHeight);
end;

function PlaceFood: Boolean;
var
  I: Integer;
  Occupied: Boolean;
begin
  if SnakeLength >= MaxSegments then
  begin
    Result := False;
    Exit;
  end;
  repeat
    FoodCell.X := Random(BoardCells);
    FoodCell.Y := Random(BoardCells);
    Occupied := False;
    for I := 0 to SnakeLength - 1 do
      if (Snake[I].X = FoodCell.X) and (Snake[I].Y = FoodCell.Y) then
      begin
        Occupied := True;
        Break;
      end;
  until not Occupied;
  Result := True;
end;

procedure ResetGame;
begin
  SnakeLength := 3;
  Snake[0].X := 11;
  Snake[0].Y := 12;
  Snake[1].X := 10;
  Snake[1].Y := 12;
  Snake[2].X := 9;
  Snake[2].Y := 12;
  DirectionX := 1;
  DirectionY := 0;
  NextDirectionX := DirectionX;
  NextDirectionY := DirectionY;
  TurnQueued := False;
  Score := 0;
  State := gsReady;
  PlaceFood;
  KillTimer(MainWindow, TimerId);
end;

function CurrentSpeed: UINT;
begin
  Result := Max(MinimumSpeed, StartSpeed - Score * 3);
end;

procedure BeginGame;
begin
  if State in [gsOver, gsComplete] then
    ResetGame;
  State := gsPlaying;
  SetTimer(MainWindow, TimerId, CurrentSpeed, nil);
  InvalidateRect(MainWindow, nil, False);
end;

procedure PauseGame;
begin
  if State = gsPlaying then
  begin
    State := gsPaused;
    KillTimer(MainWindow, TimerId);
  end
  else if State = gsPaused then
  begin
    State := gsPlaying;
    SetTimer(MainWindow, TimerId, CurrentSpeed, nil);
  end;
  InvalidateRect(MainWindow, nil, False);
end;

procedure SaveBestIfNeeded;
begin
  if Score > BestScore then
  begin
    BestScore := Score;
    SaveSetting('best.dat', IntToStr(BestScore));
  end;
end;

procedure FinishGame;
begin
  State := gsOver;
  KillTimer(MainWindow, TimerId);
  SaveBestIfNeeded;
  InvalidateRect(MainWindow, nil, False);
end;

procedure CompleteGarden;
begin
  State := gsComplete;
  KillTimer(MainWindow, TimerId);
  SaveBestIfNeeded;
  InvalidateRect(MainWindow, nil, False);
end;

procedure MoveSnake;
var
  NewHead: TCell;
  I, BodyCount: Integer;
  AteFood, HitSelf: Boolean;
begin
  DirectionX := NextDirectionX;
  DirectionY := NextDirectionY;
  TurnQueued := False;
  NewHead.X := Snake[0].X + DirectionX;
  NewHead.Y := Snake[0].Y + DirectionY;

  if (NewHead.X < 0) or (NewHead.Y < 0) or
    (NewHead.X >= BoardCells) or (NewHead.Y >= BoardCells) then
  begin
    FinishGame;
    Exit;
  end;

  AteFood := (NewHead.X = FoodCell.X) and (NewHead.Y = FoodCell.Y);
  BodyCount := SnakeLength;
  if not AteFood then
    Dec(BodyCount);
  HitSelf := False;
  for I := 0 to BodyCount - 1 do
    if (Snake[I].X = NewHead.X) and (Snake[I].Y = NewHead.Y) then
    begin
      HitSelf := True;
      Break;
    end;
  if HitSelf then
  begin
    FinishGame;
    Exit;
  end;

  if AteFood and (SnakeLength < MaxSegments) then
    Inc(SnakeLength);
  for I := SnakeLength - 1 downto 1 do
    Snake[I] := Snake[I - 1];
  Snake[0] := NewHead;

  if AteFood then
  begin
    Inc(Score);
    if not PlaceFood then
    begin
      CompleteGarden;
      Exit;
    end;
    SetTimer(MainWindow, TimerId, CurrentSpeed, nil);
  end;
  InvalidateRect(MainWindow, nil, False);
end;

procedure RequestDirection(NewX, NewY: Integer);
begin
  if State = gsReady then
    BeginGame;
  if (State <> gsPlaying) or TurnQueued then
    Exit;
  if (NewX = -DirectionX) and (NewY = -DirectionY) then
    Exit;
  NextDirectionX := NewX;
  NextDirectionY := NewY;
  TurnQueued := True;
end;

procedure ToggleTheme;
begin
  LightTheme := not LightTheme;
  if LightTheme then
    SaveSetting('theme.dat', 'light')
  else
    SaveSetting('theme.dat', 'dark');
  InvalidateRect(MainWindow, nil, True);
end;

procedure HandleKey(Key: WPARAM);
begin
  case Key of
    VK_UP, Ord('W'): RequestDirection(0, -1);
    VK_DOWN, Ord('S'): RequestDirection(0, 1);
    VK_LEFT, Ord('A'): RequestDirection(-1, 0);
    VK_RIGHT, Ord('D'): RequestDirection(1, 0);
    VK_SPACE:
      if State = gsReady then
        BeginGame
      else
        PauseGame;
    VK_RETURN:
      if State <> gsPlaying then
        BeginGame;
    Ord('R'):
      begin
        ResetGame;
        InvalidateRect(MainWindow, nil, True);
      end;
    Ord('T'): ToggleTheme;
    VK_ESCAPE:
      if State = gsPlaying then
        PauseGame;
  end;
end;

function WindowProcedure(Window: HWND; Message: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
var
  Paint: TPaintStruct;
  ClientRect: TRect;
  MinMax: PMinMaxInfo;
  MouseX, MouseY: Integer;
begin
  case Message of
    WM_CREATE:
      begin
        MainWindow := Window;
        ResetGame;
        Result := 0;
        Exit;
      end;
    WM_PAINT:
      begin
        BeginPaint(Window, Paint);
        GetClientRect(Window, ClientRect);
        DrawScene(Paint.hdc, ClientRect.Right, ClientRect.Bottom);
        EndPaint(Window, Paint);
        Result := 0;
        Exit;
      end;
    WM_ERASEBKGND:
      begin
        Result := 1;
        Exit;
      end;
    WM_TIMER:
      if WParam = TimerId then
      begin
        MoveSnake;
        Result := 0;
        Exit;
      end;
    WM_KEYDOWN:
      begin
        HandleKey(WParam);
        Result := 0;
        Exit;
      end;
    WM_LBUTTONDOWN:
      begin
        MouseX := SmallInt(LoWord(LParam));
        MouseY := SmallInt(HiWord(LParam));
        if (State <> gsPlaying) and
          (MouseX >= ActionButton.Left) and (MouseX < ActionButton.Right) and
          (MouseY >= ActionButton.Top) and (MouseY < ActionButton.Bottom) then
        begin
          BeginGame;
          InvalidateRect(Window, nil, False);
        end;
        Result := 0;
        Exit;
      end;
    WM_GETMINMAXINFO:
      begin
        MinMax := PMinMaxInfo(LParam);
        MinMax^.ptMinTrackSize.X := 620;
        MinMax^.ptMinTrackSize.Y := 720;
        Result := 0;
        Exit;
      end;
    WM_DESTROY:
      begin
        KillTimer(Window, TimerId);
        PostQuitMessage(0);
        Result := 0;
        Exit;
      end;
  end;
  Result := DefWindowProc(Window, Message, WParam, LParam);
end;

procedure RunGame;
var
  WindowClass: WNDCLASSEX;
  Message: TMsg;
  WindowWidth, WindowHeight, ScreenWidth, ScreenHeight: Integer;
begin
  WindowClass.cbSize := SizeOf(WNDCLASSEX);
  WindowClass.style := CS_HREDRAW or CS_VREDRAW;
  WindowClass.lpfnWndProc := @WindowProcedure;
  WindowClass.cbClsExtra := 0;
  WindowClass.cbWndExtra := 0;
  WindowClass.hInstance := HInstance;
  WindowClass.hIcon := LoadIcon(0, IDI_APPLICATION);
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
  WindowClass.hbrBackground := 0;
  WindowClass.lpszMenuName := nil;
  WindowClass.lpszClassName := PChar(WindowClassName);
  WindowClass.hIconSm := WindowClass.hIcon;
  if RegisterClassEx(WindowClass) = 0 then
    Halt(1);

  WindowWidth := 820;
  WindowHeight := 940;
  ScreenWidth := GetSystemMetrics(SM_CXSCREEN);
  ScreenHeight := GetSystemMetrics(SM_CYSCREEN);
  MainWindow := CreateWindowEx(0, PChar(WindowClassName), PChar(WindowTitle),
    WS_OVERLAPPEDWINDOW, (ScreenWidth - WindowWidth) div 2,
    (ScreenHeight - WindowHeight) div 2, WindowWidth, WindowHeight,
    0, 0, HInstance, nil);
  if MainWindow = 0 then
    Halt(1);

  ShowWindow(MainWindow, SW_SHOW);
  UpdateWindow(MainWindow);
  while GetMessage(Message, 0, 0, 0) do
  begin
    TranslateMessage(Message);
    DispatchMessage(Message);
  end;
end;

begin
  Randomize;
  LoadSettings;
  RunGame;
end.
