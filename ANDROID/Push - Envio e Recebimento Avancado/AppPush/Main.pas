unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ScrollBox,
  FMX.Memo, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, System.IOUtils,
  FMX.DialogService, FMX.Platform,

  {$IFDEF ANDROID}
    FMX.PushNotification.android,
    Androidapi.JNI.Provider,
    Androidapi.JNIBridge,
    Androidapi.JNI.JavaTypes,
    Androidapi.JNI.Os,
    Androidapi.jni.App,
    Androidapi.JNI.GraphicsContentViewText,
    AndroidApi.Helpers,
    Androidapi.JNI.Telephony,
    AndroidApi.JNI.Media,
    FMX.Helpers.Android,
  {$ENDIF}

  System.PushNotification, IdThreadComponent, IdBaseComponent,
  System.Notification, FMX.Media;

type
  TFormMain = class(TForm)
    ToolBar: TToolBar;
    LabelTitle: TLabel;
    MemoToken: TMemo;
    LayoutMain: TLayout;
    LabelToken: TLabel;
    ButtonGetToken: TButton;
    StyleBook: TStyleBook;
    IdThreadComponentGetMSG: TIdThreadComponent;
    NotificationCenter: TNotificationCenter;
    TimerLock: TTimer;
    ButtonOK: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ButtonGetTokenClick(Sender: TObject);
    procedure IdThreadComponentGetMSGRun(Sender: TIdThreadComponent);
    procedure TimerLockTimer(Sender: TObject);
    procedure ButtonOKClick(Sender: TObject);
  private
    { Private declarations }
    DeviceID    :String;
    DeviceToken :String;
    AppGCMCode    : String;
    FPushService  : TPushService;
    FPushServiceConnection : TPushServiceConnection;
    StringMessage : String;
    MediaPlayer : TMediaPlayer;
    //Volume
    AtualVolume : Integer;

    procedure ShowMsg;
    procedure GetToken;
    procedure OnServiceConnectionChange(Sender: TObject; AChange : TPushService.TChanges);
    procedure OnReceiveNotificationEvent(Sender: TObject; const ServiceNotification: TPushServiceNotification);
    function  AppEvent(AAppEvent : TApplicationEvent; AContext : TObject): Boolean;
    procedure Vibrate;
    procedure Unlock;
    procedure Lock;
    procedure PlayMusic;
    //Applica��o em background
    procedure GoHome;
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

const
  pushCodigoRemetente : String = ''; {C�DIGO DO REMETENTE NO FIREBASE}


implementation

{$R *.fmx}

procedure TFormMain.ButtonGetTokenClick(Sender: TObject);
begin
  Self.GetToken;
end;

procedure TFormMain.ButtonOKClick(Sender: TObject);
begin
  //Desarma o timer lock
  TimerLock.Enabled := False;
  ButtonOK.Enabled := False;
end;

procedure TFormMain.GoHome;
{$IFDEF ANDROID}
    var
    startMain : JIntent;
{$ENDIF}
begin
    {$IFDEF ANDROID}
		  startMain := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_MAIN);
		  startMain.addCategory(TJIntent.JavaClass.CATEGORY_HOME);
		  startMain.setFlags(TJIntent.JavaClass.FLAG_ACTIVITY_NEW_TASK);
		  TAndroidHelper.Activity.startActivity(startMain);
    {$ENDIF}
end;

function TFormMain.AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
var
  Text : String;
begin
  case AAppEvent of
      TApplicationEvent.WillBecomeForeground:
      begin
        //Se app ativo, inicia a Thread
        if IdThreadComponentGetMSG.Terminated then
           IdThreadComponentGetMSG.Start;
      end;
      TApplicationEvent.BecameActive:
      begin
        //Se app ativo, inicia a Thread
        if IdThreadComponentGetMSG.Terminated then
           IdThreadComponentGetMSG.Start;
      end;
      TApplicationEvent.EnteredBackground:
      begin
         //Se app entra em segundo plano termina a Thread
         if not IdThreadComponentGetMSG.Terminated then
            IdThreadComponentGetMSG.Terminate;
      end;
  end;

  //Usado para despertar o celular independente do evento
  if FileExists (TPath.Combine(TPath.GetPublicPath, 'msg')) then
  begin
    Text := TFile.ReadAllText(TPath.Combine(TPath.GetPublicPath(), 'msg'));
    if Text = '4' then  //somente se for c�digo 4, que � codigo de destravar o cell no Push
    begin
      Self.Vibrate;
      TFile.Delete(TPath.Combine(TPath.GetPublicPath(), 'msg'));
    end;

  end;

  Result := True;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  AppEventSvc : IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, AppEventSvc) then
  begin
    AppEventSvc.SetApplicationEventHandler(AppEvent);
  end;

  //C�digo do Remetente Firebase
  Self.AppGCMCode 	  := pushCodigoRemetente;
end;

procedure TFormMain.OnServiceConnectionChange(Sender: TObject; AChange: TPushService.TChanges);
begin
  //Fa�a alguma coisa aqui
end;

procedure TFormMain.OnReceiveNotificationEvent(Sender: TObject; const ServiceNotification: TPushServiceNotification);
begin
  //Fa�a alguma coisa aqui
end;

procedure TFormMain.GetToken;
begin
  //Adquire o Token e ID
  FPushService := TPushServiceManager.Instance.GetServiceByName(TPushService.TServiceNames.GCM);
  FPushService.AppProps[TPushService.TAppPropNames.GCMAppID] := Self.AppGCMCode;

	FPushServiceConnection := TPushServiceConnection.Create(FPushService);
	FPushServiceConnection.OnChange := OnServiceConnectionChange;
  FPushServiceConnection.OnReceiveNotification := OnReceiveNotificationEvent;
	FPushServiceConnection.Active := true;
  Self.DeviceID := FPushService.DeviceIDValue[TPushService.TDeviceIDNames.DeviceID];
  Self.DeviceToken := FPushService.DeviceTokenValue[TPushService.TDeviceTokenNames.DeviceToken];

  //Adiciona ao Memo
  MemoToken.Lines.Clear;
  MemoToken.Lines.Add('ID:' + Self.DeviceID);
  MemoToken.Lines.Add('Token: ' + Self.DeviceToken);

end;

procedure TFormMain.IdThreadComponentGetMSGRun(Sender: TIdThreadComponent);
var
  Text : String;
begin
  //Thread em loop para verificar se existem mensagem gravadas pela classe java
  //A Thread usada nesse procedure � uma Thread do componente TIdThreadComponent
  //Quando iniciada entra em loop automaticamente
  //Voce pode usar uma Thread tradicional, se n�o preferir o componente
  if FileExists (TPath.Combine(TPath.GetPublicPath, 'msg')) then
  begin
       //cancela todas notifica��es pendentes
			 NotificationCenter.CancelNotification('PUSH');
       Text := TFile.ReadAllText(TPath.Combine(TPath.GetPublicPath(), 'msg'));

       //Somente quando o c�digo n�o for 4
       if Text <> '4' then
       begin
			  Self.StringMessage := Text;
			  Sender.Synchronize(Self.ShowMsg);
        TFile.Delete(TPath.Combine(TPath.GetPublicPath(), 'msg'));
       end;
  end;

	Sleep(1000);
end;

procedure TFormMain.Vibrate;
{$IFDEF ANDROID}
var
  TDObject :JObject;
  TDVibrator : JVibrator;
{$ENDIF}
begin
{$IFDEF ANDROID}
    ButtonOK.Enabled := True;
  //Aqui adquire o servi�o de vibra��o do dispositivo.
  TDObject := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.VIBRATOR_SERVICE);
  TDVibrator := TJVibrator.Wrap((TDObject AS ILocalObject).GetObjectID);

  //Vibra por 20 segundos seguidos
  TDVibrator.vibrate(20000);

  //Destrava o dispositivo para o aplicativo
  Self.Unlock;

  //Habilita o timer da aplica��o em 20 segundos para cancelar o Unlock
  TimerLock.Interval := 20000;

  //Executa agendamento de lock, veja procedure abaixo
  TimerLock.Enabled := True;
{$ENDIF}
end;

procedure TFormMain.TimerLockTimer(Sender: TObject);
begin
    ButtonOK.Enabled := False;
  //Timer agendado finaliza o procedimentos
  //Lock o aparelho
  Self.Lock;

  //Libera memoria do player, faz o Intent para o backgroud e desarma o Timer
  FreeAndNil(MediaPlayer);
  Self.GoHome;
  TimerLock.Enabled := False;

end;


procedure TFormMain.Lock;
{$IFDEF ANDROID}
var

  TDAudio : JAudioManager;
  TDObjectSound :JObject;
  TDactivity : JActivity;
  TDwindow : JWindow;
{$ENDIF}
begin
{$IFDEF ANDROID}
  try
    MediaPlayer.Stop;
  except

  end;

  //Aqui adquire o servi�o de vibra��o do dispositivo.
  TDObjectSound := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.AUDIO_SERVICE);
  TDAudio := TJAudioManager.Wrap((TDObjectSound AS ILocalObject).GetObjectID);

  //retorna o volume do audio ao seu estado original
  TDAudio.setStreamVolume(TJAudioManager.JavaClass.STREAM_MUSIC, Self.AtualVolume, 0);

  //Limpar os flags de Tela
  TDactivity := TAndroidHelper.Activity;
  TDwindow   := TDactivity.getWindow;

  TDwindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_DISMISS_KEYGUARD);
  TDwindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_SHOW_WHEN_LOCKED);
  TDwindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_TURN_SCREEN_ON);
  TDwindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON);
{$ENDIF}
end;

procedure TFormMain.UnLock;
{$IFDEF ANDROID}
var
  TDAudio : JAudioManager;
  TDObjectSound :JObject;
  TDactivity : JActivity;
  TDwindow : JWindow;
{$ENDIF}
begin
{$IFDEF ANDROID}
  //destrava a tela, ativa, e mantem a luz ligada
  TDactivity := TAndroidHelper.Activity;
  TDwindow   := TDactivity.getWindow;

  TDwindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_DISMISS_KEYGUARD);
  TDwindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_SHOW_WHEN_LOCKED);
  TDwindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_TURN_SCREEN_ON);
  TDwindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON);


  //Adquirindo ao servi�o de audio
  TDObjectSound := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.AUDIO_SERVICE);
  TDAudio := TJAudioManager.Wrap((TDObjectSound AS ILocalObject).GetObjectID);

  //Adquire o volume atual para posterior retorno
  Self.AtualVolume := TDAudio.getStreamVolume(TJAudioManager.JavaClass.STREAM_MUSIC);

  //Volume ao m�ximo
  TDAudio.setStreamVolume(TJAudioManager.JavaClass.STREAM_MUSIC, 10, 0);


  //Toca o arquivo mp3
  Self.PlayMusic;
{$ENDIF}
end;

procedure TFormMain.PlayMusic;
begin
  if FileExists(TPath.Combine(TPath.GetPublicPath, 'Toque.mp3')) then
  begin
    MediaPlayer :=TMediaPlayer.Create(nil);
    MediaPlayer.FileName := TPath.Combine(TPath.GetPublicPath, 'Toque.mp3');
    MediaPlayer.Play;
  end;
end;

procedure TFormMain.ShowMsg;
begin
  TDialogService.ShowMessage(Self.StringMessage);
end;


end.
