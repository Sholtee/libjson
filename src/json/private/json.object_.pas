{*******************************************************************************

Author: Denes Solti

Unit:
    json.object_.pas

Abstract:
    Expando object.

History:
    2014.12.22: Created (Denes Solti)
    2014.02.13: Case insensitive expando object (Denes Solti)
    2016.01.27: Reviewed (Denes Solti)

*******************************************************************************}
unit json.object_;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$DEFINE ORDERED_PROPERTIES}


interface


uses
    generic.containers, com.safeobject, variant.helpers;


type
    TPropertyEnumerator = class sealed
    private
        {$IFNDEF ORDERED_PROPERTIES}
        FDispIds: TNameValueCollection<Integer>.THashEnumerator;
        {$ELSE}
        FNames: TArray<WideString>;
        FIndex: Integer;
        {$ENDIF}
        FFields: TAppendable<ISmartVariant>;
        function GetCurrent: TPair<TVarData>;
    public
        constructor Create(const AFields: TAppendable<ISmartVariant>; ADispIds: TCustomNameValueCollection<Integer>);
        {$IFNDEF ORDERED_PROPERTIES}
        destructor Destroy; override;
        {$ENDIF}
        function MoveNext: Boolean;
        property Current: TPair<TVarData> read GetCurrent;
    end;


    ISafeDispatch = interface(IUnknown)
        ['{00020400-0000-0000-C000-000000000046}']
        procedure GetTypeInfoCount(out Count: Integer); safecall;
        procedure GetTypeInfo(Index, LocaleID: Integer; out TypeInfo); safecall;
        procedure GetIDsOfNames(const IID: TGUID; Names: Pointer; NameCount, LocaleID: Integer; DispIDs: Pointer); safecall;
        procedure Invoke(DispID: Integer; const IID: TGUID; LocaleID: Integer; Flags: Word; var Params; VarResult, ExcepInfo, ArgErr: Pointer); safecall;
    end;


    IExpandoObject = interface(ISafeDispatch)
        [cMarker]
        function GetEnumerator: TPropertyEnumerator;
    end;


    TExpandoObject = class sealed(TSafeObject, IExpandoObject)
    private
        FDispIds: TNameValueCollection<Integer>;
        FFields:  TAppendable<ISmartVariant>;
        function GetIdOfName(const Name: WideString): Integer;
        { ISafeDispatch }
        procedure GetTypeInfoCount(out Count: Integer); safecall;
        procedure GetTypeInfo(Index, LocaleID: Integer; out TypeInfo); safecall;
        procedure GetIDsOfNames(const IID: TGUID; Names: Pointer; NameCount, LocaleID: Integer; DispIDs: Pointer); safecall;
        procedure Invoke(DispID: Integer; const IID: TGUID; LocaleID: Integer; Flags: Word; var Params; VarResult, ExcepInfo, ArgErr: Pointer); safecall;
        { IExpandoObject }
        function GetEnumerator: TPropertyEnumerator;
    public
        constructor Create;
        destructor Destroy; override;
        function AsVariant: TVarData;
    end;


implementation


uses
    JwaWinType, JwaWinError,

    system.error;


{$REGION TPropertyEnumerator}
constructor TPropertyEnumerator.Create;
{$IFDEF ORDERED_PROPERTIES}
var
    I: TPair<Integer>;
begin
    FFields := AFields;
    FIndex := -1;

    //
    // DispIds Data ertekei az egyes nevek pozicioi
    // -> rendezes.
    //

    SetLength(FNames, ADispIds.Count);
    for I in ADispIds do FNames[I.Data] := I.Name;
end;
{$ELSE}
begin
    FFields  := AFields;
    FDispIds := ADispIds.GetEnumerator;
end;
{$ENDIF}


{$IFNDEF ORDERED_PROPERTIES}
destructor TPropertyEnumerator.Destroy;
begin
    FDispIds.Free;
    inherited;
end;
{$ENDIF}


function TPropertyEnumerator.GetCurrent;
begin
{$IFNDEF ORDERED_PROPERTIES}
    Result.Name := FDispIds.Current.Name;
    Result.Data := FFields[ FDispIds.Current.Data ].Data^;
{$ELSE}
    Result.Name := FNames[FIndex];
    Result.Data := FFields[FIndex].Data^;
{$ENDIF}
end;


function TPropertyEnumerator.MoveNext;
begin
{$IFNDEF ORDERED_PROPERTIES}
    repeat
        Result := FDispIds.MoveNext;
    until not Result or FFields[ FDispIds.Current.Data ].Data.IsValid; // Nem ervenyes tagokat kihagyjuk
{$ELSE}
    repeat
        Inc(Findex);
    until (FIndex = FFields.Count) or FFields[FIndex].Data.IsValid; // Nem ervenyes tagokat kihagyjuk
    Result := FIndex < FFields.Count;
{$ENDIF}
end;
{$ENDREGION}


{$REGION TExpandoObject}
constructor TExpandoObject.Create;
begin
    inherited Create;
    FDispIds := TNameValueCollection<Integer>.Create;
    FFields := TAppendable<ISmartVariant>.Create;
end;


destructor TExpandoObject.Destroy;
begin
    FDispIds.Free;
    inherited;
end;


procedure TExpandoObject.GetTypeInfoCount;
begin
    Count := 0;
end;


{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
procedure TExpandoObject.GetTypeInfo;
begin
    ComError(E_NOTIMPL);
end;
{$IFDEF FPC}{$POP}{$ENDIF}


function TExpandoObject.GetIdOfName;
begin
    if not FDispIds.Get(Name, Result) then
    begin
        FFields.Append( TSmartVariant.Create );  // Egy ures elem felvete.
        Result := Pred(FFields.Count);
        FDispIds.Add(Name, Result);
    end;
end;


{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
procedure TExpandoObject.GetIDsOfNames;
var
    I: Integer;
begin
    for I := 0 to NameCount - 1 do
    begin
        //
        // A "(PINT(DispIDs) + I)^ := (PPWCHAR(Names) + I)^" nem
        // fordul mert a "+" operator CSAK PChar-ra es PByte-ra
        // mukodik =(
        //
        // (FPC-ben mukodne)
        //

        Inc(PINT(DispIDs), I);
        Inc(PPWCHAR(Names), I);
        PINT(DispIDs)^ := GetIdOfName(PPWCHAR(Names)^);
    end;
end;
{$IFDEF FPC}{$POP}{$ENDIF}


{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
procedure TExpandoObject.Invoke;
var
    Param: TVarData;
begin
    if (DispID < 0) or (DispID > FFields.Count) then
        ComError(DISP_E_MEMBERNOTFOUND);

    case Flags of
        2, 3 {DISPATCH_PROPERTYGET}:
        begin
            if not FFields[DispId].Data.IsValid then ComError(DISP_E_MEMBERNOTFOUND);
            PVarData(VarResult)^ := FFields[DispId].Data.Copy;
        end;

        4 {DISPATCH_PROPERTYPUT}, 12 {DISPATCH_PROPERTYPUT OR DISPATCH_PROPERTYPUTREF}:
        begin
            Param := PVarData(Params)^; // Params[0]
            if not Param.IsValid then ComError(DISP_E_BADVARTYPE);
            if not BOOL(Flags and 8 {DISPATCH_PROPERTYPUTREF}) then Param := Param.Copy;

            FFields[DispId] := TSmartVariant.Create(Param) // Torli a regit (ha volt)
        end;

        else ComError(HRESULT_FROM_WIN32(ERROR_INVALID_FLAGS));
    end;
end;
{$IFDEF FPC}{$POP}{$ENDIF}


function TExpandoObject.GetEnumerator;
begin
    Result := TPropertyEnumerator.Create(FFields, FDispIds);
end;


function TExpandoObject.AsVariant;
begin
    Result.VType := varDispatch;
    Result.vDispatch := nil; // Ne mutasson ervenytelen memoria-teruletre.
    IExpandoObject(Result.VDispatch) := Self;
end;
{$ENDREGION}


end.
