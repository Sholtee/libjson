{*******************************************************************************

(c) 2014 Denes Solti

Unit:
    variant.helpers.pas

Abstract:
    Variant helpers

History:
    2014.12.24: Letrehozva (Denes Solti)

*******************************************************************************}
unit variant.helpers;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}


interface


type
    ISmartVariant = interface
        ['{32943318-B13C-4DAB-8DAD-32BBA20E6AE6}']
        function Data: PVarData;
    end;


    TVarArrayEnuemrator = class sealed
    private
        FData:  TVarData;
        FIndex: Integer;
        FCurrent: ISmartVariant;
        function GetCurrent: TVarData;
    public
        constructor Create(const AData: TVarData);
        function MoveNext: Boolean;
        property Current: TVarData read GetCurrent;
    end;


    TVarHelper = record helper for TVarData
    private
        function IsValidSimpleType: Boolean;
        function IsValidArray: Boolean;
        function IsValidObject: Boolean;
        function GetItem(I: Integer): TVarData;
        procedure SetItem(I: Integer; const Data: TVarData);
        procedure SetLength(Length: Integer);
        function GetLength: Integer;
        function GetLBound: Integer;
        function GetUBound: Integer;
    public
        class function CreateArray(Length: Cardinal): TVarData; static;
        function IsValid: Boolean;
        function Copy: TVarData;
        procedure Clear;
        function GetEnumerator: TVarArrayEnuemrator;
        property LBound: Integer read GetLBound;
        property UBound: Integer read GetUBound;
        property Length: Integer read GetLength write SetLength;
        property Items[Index: Integer]: TVarData read GetItem write SetItem; default;
    end;


    TSmartVariant = class sealed(TInterfacedObject, ISmartVariant)
    private
        FData: TVarData;
        function Data: PVarData;
    public
        constructor Create(const AData: TVarData); overload;
        constructor Create; overload;
        destructor Destroy; override;
    end;


    TVariantList = record
    private
        FVariant: ISmartVariant;
        FLength:  Integer;
        function  GetData: ISmartVariant;
    public
        constructor Create(InitSize: Cardinal);
        procedure Add(Variant: ISmartVariant);
        property Data: ISmartVariant read GetData;
    end;


const
    cMarker = '{239F0046-F8F3-49F5-BE55-B0B8191ADE19}';


implementation


uses
    JwaActivex, JwaWinError,

    system.error, winapi.oleaut;


{$REGION TVarArrayEnuemrator}
constructor TVarArrayEnuemrator.Create;
begin
    FData := AData;
    FIndex := AData.LBound;
end;


function TVarArrayEnuemrator.MoveNext;
begin
    Result := FIndex <= FData.UBound;
    if Result then
    begin
        FCurrent := TSmartVariant.Create( FData[FIndex] );
        Inc(Findex);
    end;
end;


function TVarArrayEnuemrator.GetCurrent;
begin
    Result := FCurrent.Data^;
end;
{$ENDREGION}


{$REGION TVarHelper}
function TVarHelper.IsValidSimpleType;
begin
    Result := (VType < 255) {"IN" csak BYTE hossz-on megy} and (BYTE(VType) in [varInteger, varSingle, varOleStr, varNull, varBoolean]);
end;


function TVarHelper.IsValidObject;
const
    MarkerGuid: TGUID = cMarker;
var
    Obj: IUnknown;
begin
    //
    // Az egyes elemeket nem kell ellenorizni (az ExpandoObject
    // megteszi).
    //

    Result := (VType = varDispatch) and SUCCEEDED(IDispatch(VDispatch).QueryInterface(MarkerGuid, Obj));
end;


function TVarHelper.IsValidArray;
var
    I: TVarData;
begin
    Result := (VType = varArray or varVariant) and (SafeArrayGetDim(VArray) = 1);
    if Result then
        for I in Self do
            if not I.IsValid then Exit(False);
end;


function TVarHelper.IsValid;
begin
    Result := IsValidSimpleType or IsValidArray or IsValidObject;
end;


function TVarHelper.Copy;
begin
    VariantInit(Result);
    ComCheck( VariantCopy(Result, Self) );
end;


function TVarHelper.GetEnumerator;
begin
    if (VType <> varArray or varVariant) or (SafeArrayGetDim(VArray) <> 1) then
        WinError(ERROR_INVALID_PARAMETER);

    Result := TVarArrayEnuemrator.Create(Self);
end;


function TVarHelper.GetItem;
begin
    ComCheck(SafeArrayGetElement(VArray, I, @Result));
end;


procedure TVarHelper.SetItem;
begin
    ComCheck( SafeArrayPutElement(VArray, I, Data) );
end;


class function TVarHelper.CreateArray;
var
    sb: SAFEARRAYBOUND;
begin
    sb.cElements := Length;
    sb.lLbound   := 0;

    Result.vArray := SafeArrayCreate(varVariant, 1, sb);
    if not Assigned(Result.vArray) then ComError(E_OUTOFMEMORY);

    Result.VType := varArray or varVariant;
end;


procedure TVarHelper.SetLength;
var
    sb: SAFEARRAYBOUND;
begin
    Assert(VType = varArray or varVariant);

    sb.cElements := Length;
    sb.lLbound := 0;

    ComCheck( SafeArrayRedim(vArray, sb) );
end;


procedure TVarHelper.Clear;
begin
    VariantClear(Self);
end;


function TVarHelper.GetLBound;
begin
    ComCheck( SafeArrayGetLBound(VArray, 1, Result) );
end;


function TVarHelper.GetUBound;
begin
    ComCheck( SafeArrayGetUBound(VArray, 1, Result) );
end;


function TVarHelper.GetLength;
begin
    Assert(VType = varArray or varVariant);
    Result := UBound {Lehet -1} - LBound + 1;
end;
{$ENDREGION}


{$REGION SmartVariant}
constructor TSmartVariant.Create(const AData: TVarData);
begin
    inherited Create;
    FData := AData;
end;


constructor TSmartVariant.Create;
const
    {$IFDEF FPC}{$PUSH}{$WARNINGS OFF}{$ENDIF}
    EMPTY: TVarData = (VType: varEmpty; VPointer: nil);
    {$IFDEF FPC}{$POP}{$ENDIF}
begin
    Create(EMPTY);
end;


destructor TSmartVariant.Destroy;
begin
    FData.Clear;
    inherited;
end;


function TSmartVariant.Data;
begin
    Result := @FData;
end;
{$ENDREGION}


{$REGION TVariantList}
constructor TVariantList.Create;
begin
    FVariant := TSmartVariant.Create( TVarData.CreateArray(InitSize) );
    FLength := 0; // record-ban nem nullazodik ki
end;


procedure TVariantList.Add;
begin
    if FLength = FVariant.Data^.Length then
    begin
        if FVariant.Data.Length = 0 then FVariant.Data.Length := 2
        else FVariant.Data.Length := FVariant.Data.Length * 2;
    end;
    FVariant.Data^[FLength] := Variant.Data^;  // MASOLAT
    Inc(FLength);
end;


function TVariantList.GetData;
begin
    FVariant.Data^.Length := FLength;
    Result := FVariant;
end;
{$ENDREGION}


end.
