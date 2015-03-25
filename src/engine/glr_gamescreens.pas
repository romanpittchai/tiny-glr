unit glr_gamescreens;

interface

uses
  glr_core,
  glr_utils;

type
  // Usual lifecycle:
  // Hidden -> Loading -> Ready -> Paused/Unpaused -> Unloading -> Hidden
  TglrGameScreenState = ( gssHidden = 0, gssLoading, gssReady, gssPaused, gssUnloading );

  // GameScreen is something like a form, internal window.
  // Main menu is a GameScreen, pause menu is a GameScreen, even a game itself
  // is a GameScreen. Game level could be descendant of GameScreen

  { TglrGameScreen }

  TglrGameScreen = class abstract
  private
    procedure InternalUpdate(const DeltaTime: Double);
  protected
    fState: TglrGameScreenState;
    procedure SetState(NewState: TglrGameScreenState); virtual;
  public
    Name: UnicodeString;
    constructor Create(ScreenName: UnicodeString); virtual;

    property State: TglrGameScreenState read fState write SetState;

    procedure OnUpdate    (const DeltaTime: Double); virtual; abstract;
    procedure OnLoading   (const DeltaTime: Double); virtual;
    procedure OnUnloading (const DeltaTime: Double); virtual;
    procedure OnRender    ();                        virtual; abstract;

    procedure OnInput(aType: TglrInputType; aKey: TglrKey; X, Y,
      aOtherParam: Integer); virtual; abstract;
  end;

  TglrGameScreenList = TglrObjectList<TglrGameScreen>;
  TglrGameScreenStack = TglrStack<TglrGameScreen>;

  { TglrGameScreenManager }

  TglrGameScreenManager = class (TglrGameScreenList)
  protected
    fWaitForPreviousScreen: Boolean;
    function GetScreenIndex(ScreenName: UnicodeString): Integer; overload;
    function GetScreenIndex(Screen: TglrGameScreen):    Integer; overload;
  public
    ScreenStack: TglrGameScreenStack;

    constructor Create(aCapacity: LongInt = 4); override;
    destructor Destroy(); override;

    procedure ShowModal(const Index : Integer);        overload;
    procedure ShowModal(const Name  : UnicodeString);  overload;
    procedure ShowModal(const Screen: TglrGameScreen); overload;

    procedure SwitchTo(const Index : Integer);        overload;
    procedure SwitchTo(const Name  : UnicodeString);  overload;
    procedure SwitchTo(const Screen: TglrGameScreen); overload;

    procedure Back();

    procedure Update(const DeltaTime: Double);
    procedure Input(aType: TglrInputType; aKey: TglrKey; X, Y,
      aOtherParam: Integer);
    procedure Render();
  end;

implementation

{ TglrGameScreen }

procedure TglrGameScreen.SetState(NewState: TglrGameScreenState);
begin
  case fState of
    gssHidden:
      case NewState of
        gssUnloading: Exit();
        gssReady: NewState := gssLoading;
      end;

    gssLoading:
      case NewState of
        gssHidden: NewState := gssUnloading;
        gssReady, gssPaused: Exit();
      end;

    gssReady, gssPaused:
      case NewState of
        gssHidden: NewState := gssUnloading;
        gssLoading: NewState := gssReady;
      end;

    gssUnloading:
      case NewState of
        gssHidden, gssPaused: Exit();
        gssReady: NewState := gssLoading;
      end;
  end;

  fState := NewState;
end;

procedure TglrGameScreen.InternalUpdate(const DeltaTime: Double);
begin
  case fState of
    gssHidden:    ;
    gssLoading:   OnLoading(DeltaTime);
    gssReady:     OnUpdate(DeltaTime);
    gssPaused:    ;
    gssUnloading: OnUnloading(DeltaTime);
  end;
end;

constructor TglrGameScreen.Create(ScreenName: UnicodeString = '');
begin
  inherited Create();
  Name := ScreenName;
end;

procedure TglrGameScreen.OnLoading(const DeltaTime: Double);
begin
  // Load ended
  State := gssReady;
end;

procedure TglrGameScreen.OnUnloading(const DeltaTime: Double);
begin
  // Unload ended
  State := gssHidden;
end;

{ TglrGameScreenManager }

function TglrGameScreenManager.GetScreenIndex(ScreenName: UnicodeString
  ): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FCount - 1 do
    if (FItems[i].Name = ScreenName) then
      Exit(i);
end;

function TglrGameScreenManager.GetScreenIndex(Screen: TglrGameScreen): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FCount - 1 do
    if (FItems[i] = Screen) then
      Exit(i);
end;

constructor TglrGameScreenManager.Create(aCapacity: LongInt);
begin
  inherited Create(aCapacity);
  ScreenStack := TglrGameScreenStack.Create(aCapacity);
  fWaitForPreviousScreen := False;
end;

destructor TglrGameScreenManager.Destroy;
begin
  ScreenStack.Free();
  inherited Destroy;
end;

procedure TglrGameScreenManager.ShowModal(const Index: Integer);
begin
  if (index < 0) or (index >= FCount) then
    Log.Write(lCritical, 'GameScreenManager.ShowModal(index): index is out of range');

  // Pause current game screen
  if (ScreenStack.Count > 0) then
    ScreenStack.Head().State := gssPaused;

  // Push new screen as current
  ScreenStack.Push(FItems[index]);

  // Start loading
  FItems[index].State := gssLoading;

  fWaitForPreviousScreen := False;
end;

procedure TglrGameScreenManager.ShowModal(const Name: UnicodeString);
var
  index: Integer;
begin
  index := GetScreenIndex(Name);
  if (index = -1) then
    Log.Write(lCritical, 'GameScreenManager: can not find screen with name "' + Name + '"');
  ShowModal(index);
end;

procedure TglrGameScreenManager.ShowModal(const Screen: TglrGameScreen);
var
  index: Integer;
begin
  index := GetScreenIndex(Screen);
  if (index = -1) then
    Log.Write(lCritical, 'GameScreenManager: can not find screen by ref');
  ShowModal(index);
end;

procedure TglrGameScreenManager.SwitchTo(const Index: Integer);
begin
  if (index < 0) or (index >= FCount) then
    Log.Write(lCritical, 'GameScreenManager.ShowModal(index): index is out of range');

  // Unload current game screen
  if (ScreenStack.Count > 0) then
    ScreenStack.Head().State := gssUnloading;

  // Push new screen as current
  ScreenStack.Push(FItems[index]);

  // Start loading
  FItems[index].State := gssLoading;

  fWaitForPreviousScreen := True;
end;

procedure TglrGameScreenManager.SwitchTo(const Name: UnicodeString);
var
  index: Integer;
begin
  index := GetScreenIndex(Name);
  if (index = -1) then
    Log.Write(lCritical, 'GameScreenManager: can not find screen with name "' + Name + '"');
  SwitchTo(index);
end;

procedure TglrGameScreenManager.SwitchTo(const Screen: TglrGameScreen);
var
  index: Integer;
begin
  index := GetScreenIndex(Screen);
  if (index = -1) then
    Log.Write(lCritical, 'GameScreenManager: can not find screen by ref');
  SwitchTo(index);
end;

procedure TglrGameScreenManager.Back();
begin
  // Pop current and unload it
  if (ScreenStack.Count > 0) then
  begin
    ScreenStack.Pop().State := gssUnloading;
    fWaitForPreviousScreen := True;
  end;

  // Set new current state to loading
  // If it is already loaded and paused, state will be automatically set to Ready
  // ( check GameScreen.SetState() )
  if (ScreenStack.Count > 0) then
    ScreenStack.Head().State := gssLoading;
end;

procedure TglrGameScreenManager.Update(const DeltaTime: Double);
var
  i: Integer;
  needWait: Boolean;
begin
  needWait := False;
  for i := 0 to FCount - 1 do
  begin
    // Check is there any screens we should wait for
    if (FItems[i].State = gssUnloading) then
      needWait := True;

    // Prevent new screen to be loaded while other unloading
    if (fWaitForPreviousScreen) and (FItems[i].State = gssLoading) then
      continue
    else
      FItems[i].InternalUpdate(DeltaTime);
  end;

  fWaitForPreviousScreen := needWait;
end;

procedure TglrGameScreenManager.Input(aType: TglrInputType; aKey: TglrKey; X,
  Y, aOtherParam: Integer);
begin
  if (ScreenStack.Count > 0) then
    ScreenStack.Head().OnInput(aType, aKey, X, Y, aOtherParam);
end;

procedure TglrGameScreenManager.Render;
var
  i: Integer;
begin
  for i := 0 to FCount - 1 do
    if (FItems[i].State <> gssHidden) then
      FItems[i].OnRender();
end;

end.

