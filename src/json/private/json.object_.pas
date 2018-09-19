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
    2018.09.14:
        - Fixed property assignment bug (Denes Solti)
        - Property removal support (Denes Solti)
    2018.09.16: Fixed buffer overflow in GetIDsOfNames (Denes Solti)
    2018.09.17: TExpandoObject implements IKeySet (Denes Solti)

*******************************************************************************}
unit json.object_;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}


interface


uses
    generic.containers, com.safeobject, variant.helpers,

    json.types;


type
    TPropertyEnumerator = class sealed
    private
        FNames:  TArray<WideString>; // Nem masolat
        FIndex:  Integer;
        FFields: IAppendable<ISmartVariant>;
        function GetCurrent: TNameValuePair<TVarData>;
    public
        constructor Create(const AFields: IAppendable<ISmartVariant>; ADispIds: INameValueCollection<Integer>);
        function MoveNext: Boolean;
        property Current: TNameValuePair<TVarData> read GetCurrent;
    end;


    ISafeDispatch = interface
        ['{00020400-0000-0000-C000-000000000046}']
        procedure GetTypeInfoCount(out Count: Integer); safecall;
        procedure GetTypeInfo(Index, LocaleID: Integer; out TypeInfo); safecall;
        procedure GetIDsOfNames(const IID: TGUID; Names: Pointer; NameCount, LocaleID: Integer; DispIDs: Pointer); safecall;
        procedure Invoke(DispID: Integer; const IID: TGUID; LocaleID: Integer; Flags: Word; var Params; VarResult, ExcepInfo, ArgErr: Pointer); safecall;
    end;


    IExpandoObject = interface
        [cMarker]
        function GetEnumerator: TPropertyEnumerator;
    end;


    TExpandoObject = class sealed(TSafeObject, ISafeDispatch, IKeySet, IExpandoObject)
    private
        FDispIds: INameValueCollection<Integer>;
        FFields:  IAppendable<ISmartVariant>;
        function GetIdOfName(const Name: WideString): Integer;
        { ISafeDispatch }
        procedure GetTypeInfoCount(out Count: Integer); safecall;
        procedure GetTypeInfo(Index, LocaleID: Integer; out TypeInfo); safecall;
        procedure GetIDsOfNames(const IID: TGUID; Names: Pointer; NameCount, LocaleID: Integer; DispIDs: Pointer); safecall;
        procedure Invoke(DispID: Integer; const IID: TGUID; LocaleID: Integer; Flags: Word; var Params; VarResult, ExcepInfo, ArgErr: Pointer); safecall;
        { IKeySet }
        function GetKeys: TVarData; safecall;
    public
        constructor Create;
        function AsVariant: TVarData;
        { IExpandoObject }
        function GetEnumerator: TPropertyEnumerator; // publikus h az "I in Self" kifejezes mukodjon
    end;


implementation


uses
    JwaWinType, JwaWinError,

    system.error;


type
    TAr<T> = Array[0..0] of T;


{$REGION TPropertyEnumerator}
constructor TPropertyEnumerator.Create;
var
    I: TNameValuePair<Integer>;
begin
    FFields := AFields;
    FIndex := -1;

    //
    // DispIds Data ertekei az egyes nevek pozicioi
    // -> rendezes.
    //

    SetLength(FNames, ADispIds.Count);
    for I in ADispIds {$IFDEF FPC}as TCaseInsensitiveNameValueCollection<Integer>{$ENDIF} do FNames[I.Value] := I.Name;
end;


function TPropertyEnumerator.GetCurrent;
begin
    Result.Name := FNames[FIndex];
    Result.Value := FFields[FIndex].Data^; // Nem kell VariantCopy(), csak belsoleg van hasznalva
end;


function TPropertyEnumerator.MoveNext;
begin
    //
    // Ures tagokat (varEmpty = torolt v meg ertek nelkuli) kihagyjuk.
    //

    repeat
        Inc(Findex);
    until (FIndex = FFields.Count) or (FFields[FIndex].Data.VType <> varEmpty);
    Result := FIndex < FFields.Count;
end;
{$ENDREGION}


{$REGION TExpandoObject}
constructor TExpandoObject.Create;
begin
    inherited Create;
    FDispIds := TCaseInsensitiveNameValueCollection<Integer>.Create;
    FFields  := TAppendable<ISmartVariant>.Create;
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
        FFields.Append( TSmartVariant.Create );  // Egy ures elem (varEmpty) felvete.
        Result := Pred(FFields.Count);
        FDispIds.Add(Name, Result);
    end;
end;


{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
procedure TExpandoObject.GetIDsOfNames;
var
    I: INT;
    DispIdsAr: ^TAr<INT>    absolute DispIDs;
    NamesAr:   ^TAr<PWCHAR> absolute Names;
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

        DispIdsAr[I] := GetIdOfName(NamesAr[I]);
    end;
end;
{$IFDEF FPC}{$POP}{$ENDIF}


{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
procedure TExpandoObject.Invoke;
var
    VarData: TVarData;
begin
    if (DispID < 0) or (DispID > FFields.Count) then
        ComError(DISP_E_MEMBERNOTFOUND);

    case Flags of
        2, 3 {DISPATCH_PROPERTYGET}:
        begin
            VarData := FFields[DispId].Data^;

            if not VarData.IsValid or (VarData.VType = varEmpty {torolt}) then ComError(DISP_E_MEMBERNOTFOUND);
            PVarData(VarResult)^ := VarData.Copy;
        end;

        4 {DISPATCH_PROPERTYPUT}, 8 {DISPATCH_PROPERTYPUTREF}, 12 {DISPATCH_PROPERTYPUT OR DISPATCH_PROPERTYPUTREF}:
        begin
            VarData := PVarData(Params)^; // Params[0]

            if VarData.VType <> varEmpty then
            begin
                if not VarData.IsValid then ComError(DISP_E_BADVARTYPE);
                if not BOOL(Flags and 8 {DISPATCH_PROPERTYPUTREF}) then VarData := VarData.Copy;
            end;

            //
            // Ha torles (VarData.VType = varEmpty) volt akkor felsorolaskor
            // az enumerator ezt az elemet ki fogja hagyni.
            //

            FFields[DispId] := TSmartVariant.Create(VarData) // Felszabaditja a regit (ha volt)
        end;

        else WinError(ERROR_INVALID_FLAGS);
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

    //
    // Mivel referenciaszamlalt tipusra cast-olunk, ertekadaskor
    // a rendszer automatikusan megprobalna felszabaditani a
    // vDispatch altal hivatkozott memoriateruletet ha az nem NIL.
    //

    Result.vDispatch := nil;
    ISafeDispatch(Result.vDispatch) := Self;
    Assert(RefCount = 1);
end;


function TExpandoObject.GetKeys;
var
    Lst: TVariantList;
    I:   TNameValuePair<TVarData>;
    V:   TVarData;
begin
    Lst := TVariantList.Create(0);

    V.VType := varOleStr;
    for I in Self do
    begin
        //
        // Mivel "V"-rol masolat keszul, nem gond h a kovetkezo
        // iteracioban ez a mutato mar ervenyet veszti.
        //

        V.VOleStr := PWideChar(I.Name);
        Lst.Add(V);
    end;

    //
    // Nem kell masolat mert a listaval egyutt nem szabadul fel
    // a tartalom is (lasd ctor parameterek).
    //

    Result := Lst.Data.Data^;
    Lst.Data.Data^.VType := varEmpty; // HACK h ne legyen automatikus felszabaditas
end;
{$ENDREGION}


end.
