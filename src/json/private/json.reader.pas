{*******************************************************************************

Author: Denes Solti

Unit:
    json.reader.pas

Abstract:
    Json reader.

History:
    2014.12.24: Created (Denes Solti)
    2016.01.25: Reviewed (Denes Solti)

*******************************************************************************}
unit json.reader;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ELSE}
    {$WARN WIDECHAR_REDUCED OFF}
{$ENDIF}


interface


uses
    json.common, variant.helpers;


type
    IJsonReader = interface
        ['{B25495C9-7DF5-4098-803C-1078AD9DE596}']
        function ParseValue(const AString: WideString): TVarData; safecall;
    end;


    TJsonReader = class sealed(TCancelable, IJsonReader)
    private type
        TJsonToken =
        (
            None = 0,
            CurlyOpen,
            CurlyClose,
            SquaredOpen,
            SquaredClose,
            Colon,
            Comma,
            String_,
            Number,
            _True,
            _False,
            Null
        );
        TTokenSet = set of TJsonToken;

        TString = class sealed
        private
            FCurrent,
            FLast: PWideChar;
            FColumn,
            FRow: Cardinal;
            procedure IndexCheck(Index: Integer);
            function GetChar(Index: Integer): WideChar; // inline;
            function GetCharsLeft: Integer; // inline;
        public
            constructor Create(const AString: WideString);

            function ReadChar(NumChar: Integer = 1): TString;
            function SubString(Count: Integer): WideString;

            {$IFNDEF DEBUG}
            property Ptr: PWideChar read FCurrent;
            {$ENDIF}
            property CharsLeft: Integer read GetCharsLeft;
            property FirstChar: WideChar index 0 read GetChar;
            property Char[Index: Integer]: WideChar read GetChar; default;
            property Column: Cardinal read FColumn;
            property Row: Cardinal read FRow;
        end;
    private
        FStrict:   Boolean;
        FMaxDepth: Cardinal;
        procedure Fail;
        procedure DepthCheck(CurrentDepth: Cardinal);
        function AssertNextTokenIs(Current: TString; Expected: TTokenSet): TJsonToken;
        function NextToken(Current: TString): TJsonToken;
        function ParseObject(Current: TString; CurrentDepth: Cardinal): ISmartVariant;
        function ParseArray(Current: TString; CurrentDepth: Cardinal): ISmartVariant;
        function ParseValue(Current: TString; CurrentDepth: Cardinal): ISmartVariant; overload;
        function ParseString(Current: TString): ISmartVariant;
        function ParseNumber(Current: TString): ISmartVariant;
        function ParseProperty(Current: TString): WideString;
        { IJsonReader }
        function ParseValue(const AString: WideString): TVarData; overload; safecall;
    public
        constructor Create(AStrict: Boolean = False; AMaxDepth: Cardinal = 25; ACancellationToken: THandle = 0);
    end;


implementation


uses
    JwaWinType, JwaWinError,

    {$IFDEF DEBUG}
    JwaWinBase,
    {$ENDIF}

    system.error, system.strings,

    {$IFDEF FPC}
    generic.containers,
    {$ENDIF}

    {$IFNDEF FPC}
    JwaShLwApi,
    {$ENDIF}

    json.object_;


{$REGION Helpers}
const
    {$IFDEF FPC}{$PUSH}{$WARNINGS OFF}{$ENDIF}
    NULL_:  TVarData = (VType: varNull;    VPointer: nil);
    TRUE_:  TVarData = (VType: varBoolean; VBoolean: True);
    FALSE_: TVarData = (VType: varBoolean; VBoolean: False);
    {$IFDEF FPC}{$POP}{$ENDIF}
    NULL_GUID: TGUID = '{00000000-0000-0000-0000-000000000000}';


{$IFDEF FPC}
function StrToIntExW(pSz: PWideChar; dwFlags: DWORD; out I: INT): BOOL; stdcall; external 'Shlwapi.dll';
{$ENDIF}


{$IFDEF FPC}
procedure DispPropertyPut(Disp: IDispatch; const PropertyName: WideString; Value: PVarData);
{$ELSE}
procedure DispPropertyPut(Disp: IDispatch; PropertyName: PWideChar; Value: PVarData);
{$ENDIF}
var
    DispId: Integer;
    Args: record
        Arg:        PVarData;
        NamedArgs:  PINT;
        cArgs:      UINT;
        cNamedArgs: UINT;
    end;
begin
    ComCheck(Disp.GetIDsOfNames(
        NULL_GUID,
        Pointer(TArray<PWideChar>.Create( PWideChar(PropertyName) )),  // PPWideChar...
        1,
        0,
        @DispId));

    Args.Arg        := Value;
    Args.NamedArgs  := nil;
    Args.cArgs      := 1;
    Args.cNamedArgs := 0;

    ComCheck(Disp.Invoke(
        DispId,
        NULL_GUID,
        0,
        4 {DISPATCH_PROPERTYPUT},
        Args,
        nil,
        nil,
        nil));
end;
{$ENDREGION}


{$REGION TString}
constructor TJsonReader.TString.Create;
begin
    FCurrent := PWideChar(AString);
    FLast    := FCurrent + AString.Length;
end;


function TJsonReader.TString.ReadChar;
begin
    IndexCheck(NumChar);
    Inc(FCurrent, NumChar);

    if FirstChar <> #10 then Inc(FColumn) else // Uj sor?
    begin
        Inc(FRow);
        FColumn := 0;
    end;

    Result := Self;
end;


procedure TJsonReader.TString.IndexCheck;
begin
    if (Index < 0) or (Index > CharsLeft) then
        WinError(ERROR_INVALID_INDEX);
end;


function TJsonReader.TString.GetChar;
begin
    IndexCheck(Index);
    Result := (FCurrent + Index)^;
end;


function TJsonReader.TString.SubString;
begin
    IndexCheck(Count);
    SetString(Result, FCurrent, Count);
end;


function TJsonReader.TString.GetCharsLeft;
begin
    Result := IntPtr(FLast - FCurrent);
end;
{$ENDREGION}


{$REGION TJsonReader}
constructor TJsonReader.Create;
begin
    inherited Create(ACancellationToken);

    FStrict   := AStrict;
    FMaxDepth := AMaxDepth;
end;


procedure TJsonReader.DepthCheck;
begin
    if CurrentDepth > FMaxDepth then
        WinError(ERROR_STACK_OVERFLOW);
end;


function TJsonReader.ParseValue(const AString: WideString): TVarData;
var
    Context: TString;
begin
    Context := TString.Create(AString);
    try
        Result := ParseValue(Context, 0).Data.Copy;
    finally
        Context.Free;
    end;
end;


function TJsonReader.ParseValue(Current: TString; CurrentDepth: Cardinal): ISmartVariant;
begin
    case NextToken(Current) of
        Number:      Result := ParseNumber(Current);
        String_:     Result := ParseString(Current);
        SquaredOpen: Result := ParseArray(Current, CurrentDepth);
        CurlyOpen:   Result := ParseObject(Current, CurrentDepth);
        _True:
        begin
            Result := TSmartVariant.Create(TRUE_);
            Current.ReadChar(4);
        end;
        _False:
        begin
            Result := TSmartVariant.Create(FALSE_);
            Current.ReadChar(5);
        end;
        Null:
        begin
            Result := TSmartVariant.Create(NULL_);
            Current.ReadChar(4);
        end;
        else Fail;
    end;
end;


procedure TJsonReader.Fail;
begin
    WinError(ERROR_INVALID_DATA);
end;


function TJsonReader.ParseProperty;
var
    I: Integer;
begin
    if not FStrict then
    begin
        //
        // Hany karakterbol all a property (kivetel ha a
        // string vegere ertunk).
        //

        I := 0;
        while Current[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] do
            Inc(I);

        //
        // Property nevenek kivagasa.
        //

        if I > 0 then
        begin
            Result := Current.SubString(I);
            Current.ReadChar(I); // Ugras tovabb
            Exit;
        end;
    end;
    Fail;
end;


function TJsonReader.AssertNextTokenIs;
begin
    Result := NextToken(Current);
    if not (Result in Expected) then
        Fail;
end;


function TJsonReader.ParseObject;
var
    PropertyName: {$IFDEF FPC}WideString{$ELSE}PWideChar{$ENDIF};
begin
    Current.ReadChar;  // "{"-n allunk

    //
    // Melyseg ellenorzes...
    //

    if NextToken(Current) <> CurlyClose then DepthCheck( Succ(CurrentDepth) );

    //
    // Eredmeny.
    //

    Result := TSmartVariant.Create( TExpandoObject.Create.AsVariant );

    while NextToken(Current) <> CurlyClose do // Lezaro "}"-n vagyunk?
    begin
        //
        // Property neve
        //

        if AssertNextTokenIs(Current, [String_, None]) = String_ then
            PropertyName := ParseString(Current).Data.VOleStr
        else
            PropertyName := {$IFNDEF FPC}PWideChar({$ENDIF} ParseProperty(Current) {$IFNDEF FPC}){$ENDIF};

        //
        // Proerty nev es erteket elvalaszto ":"
        //

        AssertNextTokenIs(Current, [Colon]);
        Current.ReadChar;

        //
        // Ertek kiolvasasa
        //

        DispPropertyPut(
            IDispatch(Result.Data.VDispatch),
            PropertyName,
            ParseValue(Current, Succ(CurrentDepth)).Data);

        //
        // Ha "," kovetkezik, azt ugorjuk at, kulonben a
        // lezaro "}"-nak kell jonnie.
        //

        if NextToken(Current) = Comma then Current.ReadChar
        else AssertNextTokenIs(Current, [CurlyClose]);
    end;

    //
    // Lezaro "}" atugrasa (ha nem vagyunk a string vegen).
    //

    if Current.CharsLeft > 0 then Current.ReadChar;
end;


function TJsonReader.ParseArray;
var
    Ar: TVariantList; // Kezelve van az elettartama
begin
    Current.ReadChar; // ugras a "[" utan

    //
    // Melyseg ellenorzes
    //

    if NextToken(Current) <> SquaredClose then DepthCheck( Succ(CurrentDepth) );

    //
    // Eredmeny
    //

    Ar := TVariantList.Create(2);

    while NextToken(Current) <> SquaredClose do // Elertuk a lezaro "]"-t
    begin
        //
        // Ertek felvetele.
        //

        Ar.Add(ParseValue(Current, Succ(CurrentDepth)));

        //
        // Ha "," kovetkezik, azt ugorjuk at.
        //

        if NextToken(Current) = Comma then Current.ReadChar;
    end;

    //
    // Lezaro "]" atugrasa es eredmeny letrehozasa.
    //

    if Current.CharsLeft > 0 then Current.ReadChar;
    Result := Ar.Data;
end;


function TJsonReader.ParseNumber;
const
    GetType: Array[Boolean] of TVarType = (varInteger, varSingle);
var
    I:      Integer;
    Number: WideString;
    ErrPos: Integer;
    Float:  Boolean;
begin
    Result := TSmartVariant.Create;

    //
    // Karakterek beolvasasa.
    //

    I := 0;
    Float := False;

    while (I <= Current.CharsLeft) and (Current[I] in ['0'..'9', '+', '-', '.']) do
    begin
        if Current[I] = '.' then Float := True;
        Inc(I);
    end;

    //
    // A szamsort tartalmazo szekcio masolasa, majd konvertalas.
    //

    Number := Current.SubString(I);
    Current.ReadChar(I); // Ugras tovabb

    if Float then Val(Number, Result.Data.VSingle, ErrPos)
    else Val(Number, Result.Data.VInteger, ErrPos);

    if ErrPos <> 0 then Fail;

    //
    // Tipus beallitasa.
    //

    Result.Data.VType := GetType[Float];

    {$IFDEF DEBUG}
    OutputDebugStringW(PWideChar(Number));
    {$ENDIF}
end;


function TJsonReader.ParseString;
var
    SectionLength,
    I, J:          Integer;
    S:             WideString;
    Str:           TStringBuilder;
begin
    //
    // Elofeltetelek ellenorzese.
    //

    if FStrict and (Current.FirstChar = '''') then Fail;

    //
    // A "-k kozti karakterek beolvasasa.
    //

    Current.ReadChar; // " <- utani elso karakter

    Str := TStringBuilder.Create(0);
    I := 0;

    while not (Current[I] in ['''', '"']) do
    begin
        //
        // Van escape-elt tartalom?
        //

        if Current[I] = '\' then
        begin
            //
            // Az escape karakterig hany karaktert olvastunk be?
            //

            SectionLength := I;

            //
            // Az escape jelzo utani elso karakter feldolgozas.
            //

            Inc(I);
            case Current[I] of
                '"'  : S:= '"';
                '''' : S:= '''';
                't'  : S:= #9;
                'b'  : S:= #8;
                'n'  : S:= #10;
                'r'  : S:= #13;
                'f'  : S:= #12;
                '\'  : S:= '\';
                '/'  : S:= '/';
                'u'  :
                begin
                    //
                    // Unicode karakter feldolgozasa (kivetel ha
                    // a karakterlanc vegere ertunk).
                    //

                    S := '0x0000'; // StrToIntEx()-nel "0x"-el kell h kezdodjon
                    for J := 3 to 6 do
                    begin
                        Inc(I);
                        S[J] := Current[I];
                    end;

                    //
                    // Konverzio...
                    //

                    if not StrToIntExW(PWideChar(S), 1 {STIF_SUPPORT_HEX}, J) then Fail;
                    S := WideChar(J); // Fordito megoldja...
                end;
                else Fail;
            end;

            Str.Append(  // Tartalom az escape-elt reszig
                {$IFDEF DEBUG}
                Current.SubString(SectionLength)
                {$ELSE}
                Current.Ptr, SectionLength
                {$ENDIF});
            Str.Append(S); // A dekodolt escape-elt resz

            //
            // Eddig feldolgozott resz atugrasa (biztosan kell meg
            // utana adatnak lennie ha mas nem lezaro "-nak).
            //

            Current.ReadChar( Succ(I) );
            I := 0;
            Continue;
        end;

        //
        // Ugras a kovetkezo karakterre.
        //

        Inc(I);
    end;

    //
    // Maradek masolasa.
    //

    Str.Append(
        {$IFDEF DEBUG}
        Current.SubString(I)
        {$ELSE}
        Current.Ptr, I
        {$ENDIF});
    Current.ReadChar(I);

    if Current.CharsLeft > 0 then Current.ReadChar; // Lezaro " atugrasa

    //
    // All ok
    //

    Result := TSmartVariant.Create;

    Result.Data.vOleStr := Str.ToOleString;
    Result.Data.VType   := varOleStr;

    {$IFDEF DEBUG}
    OutputDebugStringW(Result.Data.VOleStr);
    {$ENDIF}
end;


function TJsonReader.NextToken;
begin
    //
    // Specialis eset, ha meg nem olvastunk be semmit es a
    // karakterlanc ures.
    //

    if Current.CharsLeft = 0 then Fail;

    //
    // Kell egyaltalan vmit csinalni?
    //

    CheckCancelled;

    repeat
        //
        // Aktualis karakter(ek) megfeleltetese.
        //

        case Current.FirstChar of
            '{' :
                Exit(CurlyOpen);
            '}' :
                Exit(CurlyClose);
            '[' :
                Exit(SquaredOpen);
            ']' :
                Exit(SquaredClose);
            ',' :
                Exit(Comma);
            ':' :
                Exit(Colon);
            '"','''' :
                Exit(String_);
            '0'..'9', '+', '-' :
                Exit(Number);
            'f', 'F' : if (Current.CharsLeft >= 4) and
                (Current[1] in ['a', 'A']) and
                (Current[2] in ['l', 'L']) and
                (Current[3] in ['s', 'S']) and
                (Current[4] in ['e', 'E']) then
                Exit(_False);
            't', 'T' : if (Current.CharsLeft >= 3) and
                (Current[1] in ['r', 'R']) and
                (Current[2] in ['u', 'U']) and
                (Current[3] in ['e', 'E']) then
                Exit(_True);
            'n', 'N' : if (Current.CharsLeft >= 3) and
                (Current[1] in ['u', 'U']) and
                (Current[2] in ['l', 'L']) and
                (Current[3] in ['l', 'L']) then
                Exit(Null);

            //
            // WhiteSpace-ek atugrasa (kivetel ha a string vegere ertunk).
            //

            else if Current.FirstChar.IsSpace then
            begin
                Current.ReadChar;
                Continue;
            end;
        end;

        //
        // Nem lehetett felimserni a token-t.
        //

        Exit(None);
    until False;

    Assert(False);
end;
{$ENDREGION}


end.
