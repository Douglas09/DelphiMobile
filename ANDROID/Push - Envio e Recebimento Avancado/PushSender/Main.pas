unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.EditBox, FMX.NumberBox, FMX.Edit, FMX.ScrollBox, FMX.Memo,
  FMX.Controls.Presentation, FMX.DialogService, System.JSON,REST.Client,
  REST.Types, FMX.ListBox;

type
  TFormMain = class(TForm)
    Label1: TLabel;
    MemoToken: TMemo;
    Label2: TLabel;
    EditMessage: TEdit;
    Label3: TLabel;
    ButtonSend: TButton;
    ComboBoxCommand: TComboBox;
    procedure ButtonSendClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    CodigoAPIGCM : String;
    GoogleService : String;
    procedure SendPush(Code : String; Msg : String; Token : String);
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

const
  pushChaveHerdada : String = ''; {CHAVE HERDADA DO FIREBASE}
  pushApi : String = 'https://fcm.googleapis.com/fcm/send'; {URL DA API DO FIREBASE}
implementation

{$R *.fmx}

procedure TFormMain.ButtonSendClick(Sender: TObject);
var
  Codigo : String;
begin
  //Valida token se existir
  if MemoToken.Lines.Count <= 0 then
  begin
    TDialogService.ShowMessage('Voc� precisa informar o Token do dispositivo');
    exit;
  end;

  //Codigo est�o explicito na classe java
  //Aqui usei o indice do ComboBox
  //(ComboBoxCommand.ItenIndex = 0) -> Codigo 1 relacionado a abrir o aplicativo
  //(ComboBoxCommand.ItenIndex = 1) -> Codigo 2 relacionado a abrir o aplicativo e mostrar menssagem
  //(ComboBoxCommand.ItenIndex = 2) -> Codigo 3 relacionado somente a Notifica��o PUSH
  //(ComboBoxCommand.ItenIndex = 3) -> Codigo 4 relacionado somente destravar o celular, vibrar e tocar


  if (ComboBoxCommand.ItemIndex = 1)
      AND (EditMessage.Text.IsEmpty) then
  begin
    TDialogService.ShowMessage('Voc� precisa informar a mensagem');
    exit;
  end;

  if (ComboBoxCommand.ItemIndex = 2)
     AND (EditMessage.Text.IsEmpty) then
  begin
    TDialogService.ShowMessage('Voc� precisa informar a mensagem');
    exit;
  end;

  //Soma 1, para igular o c�digo da classe Java
  Codigo := IntToStr(ComboBoxCommand.ItemIndex + 1);
  Self.SendPush(Codigo, EditMessage.Text, MemoToken.Text);

end;
procedure TFormMain.FormCreate(Sender: TObject);
begin
  //Chave herdada do servidor Firebase
  Self.CodigoAPIGCM   := pushChaveHerdada;

  //Endpoint da API do Firebase
  Self.GoogleService  := pushApi;
end;

procedure TFormMain.SendPush(Code: String; Msg: String; Token: String);
var
  FRESTRequest : TRESTRequest;
	FRESTResponse : TRESTResponse;
	FRESTClient : TRESTClient;
  JSONObjectNotification, LJSONObjectMain : TJSONObject;
begin
  JSONObjectNotification := TJSONObject.Create;
  LJSONObjectMain := TJSONObject.Create;


  FRESTRequest   := TRESTRequest.Create(nil);
  FRESTResponse  := TRESTResponse.Create(FRESTRequest);
  FRESTClient    := TRESTClient.Create('');

  FRESTClient.Accept 		      := 'application/json';
	FRESTClient.AcceptCharset   := 'UTF-8';
	FRESTRequest.Client 	      := FRESTClient;
	FRESTRequest.Response 	    := FRESTResponse;

  //Adiciona um par JSON contendo a mensagem que ser� exibida
  JSONObjectNotification.AddPair('message', Msg);

  //Adiciona o c�digo (id_push) para manipula��o da classe Java
  JSONObjectNotification.AddPair('id_push', Code);

	LJSONObjectMain.AddPair('notification', JSONObjectNotification);
	LJSONObjectMain.AddPair('to', Token);


  FRESTRequest.AddAuthParameter('Authorization', 'key=' + Self.CodigoAPIGCM, pkHTTPHEADER, [poDoNotEncode]);
  FRESTClient.BaseURL := Self.GoogleService;
	FRESTRequest.Method := rmPOST;
	FRESTRequest.Body.Add(LJSONObjectMain);
  FRESTRequest.Execute;

  FreeAndNil(LJSONObjectMain);
  FreeAndNil(FRESTRequest);


end;

end.
