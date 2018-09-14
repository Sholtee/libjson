{*******************************************************************************

Author: Denes Solti

Unit:
    json.writer.pas

Abstract:
    Json writer.

History:
    2014.12.27: Created (Denes Solti)
    2016.01.27: Reviewed (Denes Solti)

*******************************************************************************}
unit json.writer;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ELSE}
    {$WARN WIDECHAR_REDUCED OFF}
{$ENDIF}


interface


uses
    json.types, json.common, system.strings;


type
    TJsonWriter = class sealed(TCancelable, IJsonWriter)
    private const
        NewLineFmt: WideString = '%r%n%1!.*s!';
    private
        FBuilder: TStringBuilder;
        FIndents: WideString;
        FOptions: TFormatOptions;
        procedure StringToJsonString(const AData: TVarData);
        procedure ObjectToJsonString(const AData: TVarData; ACurrentIndent: Cardinal);
        procedure ArrayToJsonString(const AData: TVarData; ACurrentIndent: Cardinal);
        procedure AnyToString(const AData: TVarData; ACurrentIndent: Cardinal);
        { IJsonWriter }
        function Write(const AData: TVarData): PWideChar; safecall;
        function CreateJsonObject: TVarData; safecall;
    public
        constructor Create(
            AFormatOptions:     TFormatOptions = [];
            AMaxDepth:          Cardinal = 255;
            ACancellationToken: THandle = 0);
    end;


implementation


uses
    JwaWinBase, JwaWinError,

    winapi.oleaut,

    generic.containers,

    system.error,

    variant.helpers,

    json.object_;


{$REGION Helpers}
function CalcCCh(Current, Start: PWideChar): Cardinal;
begin
    {$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
    Result := (UIntPtr(Current) - UIntPtr(Start)) div SizeOf(WideChar);
    {$IFDEF FPC}{$POP}{$ENDIF}
end;


function VarToText(const AData: TVarData): WideString;
var
    Dst: ISmartVariant;
    I:   Integer;
begin
    Dst := TSmartVariant.Create;  // Empty
    ComCheck( VariantChangeType(Dst.Data^, AData, 2 {VARIANT_ALPHABOOL}, varOleStr) );

    //
    // Eredmeny konvertalasa WideString-e
    //

    SetString(Result, Dst.Data.VOleStr, lstrlenW(Dst.Data.VOleStr));

    //
    // Lebegopontos szamoknal "." helyett "," szerepel =(
    //

    if AData.VType in [varSingle, varDouble] then
        for I := 1 to High(Result) do if Result[I] = ',' then
        begin
            Result[I] := '.';
            Break;
        end;
end;
{$ENDREGION}


{$REGION TJsonWriter}
constructor TJsonWriter.Create;
begin
    inherited Create(ACancellationToken);

    FBuilder := TStringBuilder.Create(0);
    FIndents := StringOfChar(Chr(9){TAB}, AMaxDepth){$IFDEF FPC}.ToWide{$ENDIF};
    FOptions := AFormatOptions;
end;


function TJsonWriter.Write;
begin
    //
    // Ha volt a taroloban korabbrol adat, azt most toroljuk.
    //

    if FBuilder.Position <> 0 then
    begin
        FCancelCounter  := 0;
        FBuilder.Length := 0;
    end;

    //
    // Eredmeny letrehozasa.
    //

    AnyToString(AData, 0);
    FBuilder.Append(#0, 1); // String lezarasa.
    Result := FBuilder.AccessData;
end;


procedure TJsonWriter.StringToJsonString;
const
    HexFmt: WideString = '\u%1!04X!';
var
    S,
    Start: PWideChar;
begin
    FBuilder.Append('"');
    S := AData.VOleStr;
    Start := S;
    while S^ <> #0 do
    begin
        //
        // Escape-elendo karakterunk van?
        //

        if (S^ in ['"','/','\', #8, #9, #10, #12, #13]) or (S < ' ') or (Ord(S^) >= 128) then
        begin
            FBuilder.Append(Start, CalcCCh(S, Start));
            case S^ of
                '\' : FBuilder.Append('\\');
                '/' : FBuilder.Append('\/');
                '"' : FBuilder.Append('\"');
                #8  : FBuilder.Append('\b');
                #9  : FBuilder.Append('\t');
                #10 : FBuilder.Append('\n');
                #12 : FBuilder.Append('\f');
                #13 : FBuilder.Append('\r');
                else  FBuilder.Append( HexFmt.Args([Ord(S^)]) );
            end;
            Start := S + 1;
        end;

        //
        // Ha kell escape-elni, ha nem ugorjunk a kov karakterre.
        //

        Inc(S);
    end;

    //
    // Maradék...
    //

    FBuilder.Append(Start, CalcCCh(S, Start));
    FBuilder.Append('"');
end;


procedure TJsonWriter.ObjectToJsonString;
const
    MemberFmt: WideString = '"%1!s!"';
var
    Prop:  TPair<TVarData>; // TVarData NEM masolat
    First: Boolean;
begin
    FBuilder.Append('{');
    First := True;

    for Prop in IUnknown(AData.VDispatch) as IExpandoObject {Kivetel ha nem valid} do
    begin
        //
        // Elozo sor lezarasa uj sor beszurasa.
        //

        if not First then FBuilder.Append(',') else First := False;

        if not (foSingleLineObject in FOptions) then
            FBuilder.Append(NewLineFmt.Args([Succ(ACurrentIndent), FIndents]));

        //
        // Property neve es erteke.
        //

        if foDoNotQuoteMembers in FOptions then FBuilder.Append(Prop.Name)
        else FBuilder.Append(MemberFmt.Args([Prop.Name]));

        FBuilder.Append(':');
        AnyToString(Prop.Data, Succ(ACurrentIndent));
    end;

    //
    // Lezaras...
    //

    if not First and not (foSingleLineObject in FOptions) then
        FBuilder.Append(NewLineFmt.Args([ACurrentIndent, FIndents]));

    FBuilder.Append('}');
end;


procedure TJsonWriter.ArrayToJsonString;
var
    Item:  TVarData; // NEM masolat
    First: Boolean;
begin
    FBuilder.Append('[');
    First := True;

    for Item in AData {Megfelelo kivetel ha nem valid} do
    begin
        //
        // Elozo sor lezarasa uj sor beszurasa.
        //

        if not First then FBuilder.Append(',') else First := False;

        if not (foSingleLineArray in FOptions) then
            FBuilder.Append(NewLineFmt.Args([Succ(ACurrentIndent), FIndents]));

        //
        // Ertek kiirasa.
        //

        AnyToString(Item, Succ(ACurrentIndent));
    end;

    //
    // Lezaras...
    //

    if not First and not (foSingleLineArray in FOptions) then
        FBuilder.Append(NewLineFmt.Args([ACurrentIndent, FIndents]));

    FBuilder.Append(']');
end;


procedure TJsonWriter.AnyToString;
begin
    if ACurrentIndent > Cardinal(FIndents.Length) then WinError(ERROR_BUFFER_OVERFLOW);

    CheckCancelled;

    case AData.VType of
        varNull:     FBuilder.Append('null');
        // A FormatMessage() NEM tamogatja a lebegopontos szamokat (MSDN)
        varInteger,
        varSingle,
        varBoolean:  FBuilder.Append( VarToText(AData) );
        varOleStr:   StringToJsonString(AData);
        varDispatch: ObjectToJsonString(AData, ACurrentIndent);
        varArray or
        varVariant:  ArrayToJsonString(AData, ACurrentIndent);
        else ComError(E_INVALIDARG);
    end;
end;


function TJsonWriter.CreateJsonObject;
begin
    Result := TExpandoObject.Create.AsVariant;
end;
{$ENDREGION}


end.
