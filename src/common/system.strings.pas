{*******************************************************************************

Author: Denes Solti

Unit:
    system.strings.pas

Abstract:
    Strings.

History:
    2014.11.08: Created (Denes Solti)
    2014.12.15: Reviewed (Denes Solti)
    2015.02.14: TWideStringMarshaller (Denes Solti)
    2015.04.12: WideStringHelper.IsNilOrEmpty, (Denes Solti)
                WideStringHelper.SubString (Denes Solti)
    2016.01.05: TStringBuilder (Denes Solti)
    2016.01.25: WideCharHelper (Denes Solti)
    2018.09.11: Hint removal (Denes Solti)

*******************************************************************************}
unit system.strings;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


type
    AnsiStringHelper = record helper for AnsiString
    public
        function Args(const Params: Array of const): AnsiString;
        function ToWide: WideString;
        function Length: Integer;
    end;


    WideStringHelper = record helper for WideString
    public
        function IsNilOrEmpty: Boolean;
        function SubString(Offset: Integer; Count: Integer = MaxInt): WideString;
        function Args(const Params: Array of const): WideString;
        function ToMultiByte: AnsiString;
        function LowerCase: WideString;
        function Equals(const Str: WideString): Boolean;
        function StartsWith(const Str: WideString): Boolean;
        function SubStringAt(Offset: Integer; const SubString: WideString): Boolean;
        function IndexOf(What: WideChar; StartIndex: Integer = 1; First: Boolean = True): Integer;
        function Length: Integer;
        procedure SetLength(NewLength: Integer);
    end;


    WideCharHelper = record helper for WideChar
    public
        function IsSpace: Boolean;
    end;


    IWideStringMarshaller = interface
        function GetValue: PWideChar;
        property Value: PWideChar read GetValue;
    end;


    TWideStringMarshaller = class sealed(TInterfacedObject, IWideStringMarshaller) // String -> PChar konverter (referencia szamlalt)
    private
        FValue: WideString;
        { IWideStringMarshaller }
        function GetValue: PWideChar;
    public
        constructor Create(const S: WideString);
    end;


    TStringBuilder = record
    private
        FBuffer:   WideString;
        FPosition: Integer;
        procedure SetLength(NewLength: Integer);
        function GetChar(Index: Integer): WideChar;
    public
        constructor Create(InitialSize: Integer);
        procedure Append(const p: PWideChar; Len: Integer{$IFNDEF FPC} = -1{$ENDIF}); overload;
        procedure Append(const p: WideString); overload;
        function ToString: WideString;
        function ToOleString: PWideChar;
        function AccessData: PWideChar; // NEM biztos h NULL terminalt!!!
        property Length: Integer write SetLength;
        property Position: Integer read FPosition;
        property Chars[Index: Integer]: WideChar read GetChar; default;
    end;


implementation


uses
    JwaWinBase, JwaWinNls, {$IFNDEF FPC}JwaShlwApi,{$ENDIF} JwaWinUser,

    JwaWinType, JwaWinError,

    system.error {$IFDEF FPC}, generic.containers{$ENDIF};


{$REGION Helpers}
{$IFDEF FPC}
const
    ShLwApi = 'shlwapi.dll';

function StrChrIW(lpStart: PWideChar; wMatch: WideChar): PWideChar; stdcall; external ShLwApi;
function StrRChrIW(lpStart, lpEnd: PWideChar; wMatch: WideChar): PWideChar; stdcall; external ShLwApi;


//
// Az FPC (2.7.1) nagyon faszan nem talalja meg a forditoba epitett
// fv-eket ha System.FvNev formaban hivom =(
//
// Ezert kiszervezem ide mert itt nem kell oket prefixelni.
//

function WideStringLength(const S: WideString): Integer; inline;
begin
    Result := Length(S);
end;


function AnsiStringLength(const S: AnsiString): Integer; inline;
begin
    Result := Length(S);
end;


procedure AnsiStringSetLength(out S: AnsiString; NewLength: Integer); inline;
begin
    SetLength(S, NewLength);
end;


procedure WideStringSetLength(out S: WideString; NewLength: Integer); inline;
begin
    SetLength(S, NewLength);
end;
{$ENDIF}


function ConvertConstArray(const Ar: Array of const): TArray<Pointer>;
var
    I: Integer;
begin
    SetLength(Result, Length(Ar));

    for I := 0 to Length(Ar) - 1 do
    begin
        if Byte(Ar[I].VType) in [vtExtended, vtCurrency, vtObject, vtClass, vtVariant, vtInterface] then
            ComError(E_INVALIDARG);
        Result[I] := Ar[I].VPointer;
    end;
end;


function SysAllocStringLen(src: PWideChar; ui: UINT): PWideChar; stdcall; external 'oleaut32.dll';
{$ENDREGION}


{$REGION AnsiStringHelper}
function AnsiStringHelper.Args;
var
    Arguments: TArray<Pointer>;
    Buf:       PAnsiChar;
    I:         Integer;
begin
    Arguments := ConvertConstArray(Params);

    Buf := nil;
    I := FormatMessageA(
        FORMAT_MESSAGE_FROM_STRING or FORMAT_MESSAGE_ARGUMENT_ARRAY or FORMAT_MESSAGE_ALLOCATE_BUFFER,
        PAnsiChar(Self),
        0,
        0,
        @Buf,
        0,
        Pointer(Arguments));
    WinCheck(I > 0);
    try
        SetString(Result, Buf, I);
    {$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
    finally LocalFree(HLOCAL(Buf)) end;
    {$IFDEF FPC}{$POP}{$ENDIF}
end;


function AnsiStringHelper.ToWide;
var
    Len: Integer;
begin
    SetLength(Result, Self.Length);
    if Result.Length = 0 then Exit;

    Len := MultiByteToWideChar(
        CP_UTF8,
        0,
        PAnsiChar(Self), Self.Length,
        PWideChar(Result), Result.Length);
    WinCheck(Len > 0); SetLength(Result, Len);
end;

function AnsiStringHelper.Length;
begin
    Result := {$IFDEF FPC}AnsiStringLength{$ELSE}System.Length{$ENDIF}(Self);
end;
{$ENDREGION}


{$REGION WideStringHelper}
function WideStringHelper.IsNilOrEmpty;
begin
    Result := (Self.Length = 0) or (Self[1] = #0);
end;


function WideStringHelper.SubString;
begin
    if Offset > High(Self) then Result := ''
    else Result := Copy(Self, Offset, Count);
end;


function WideStringHelper.Args;
var
    Arguments: TArray<Pointer>;
    Buf:       PWideChar;
    I:         Integer;
begin
    Arguments := ConvertConstArray(Params);

    Buf := nil;
    I := FormatMessageW(
        FORMAT_MESSAGE_FROM_STRING or FORMAT_MESSAGE_ARGUMENT_ARRAY or FORMAT_MESSAGE_ALLOCATE_BUFFER,
        PWideChar(Self),
        0,
        0,
        @Buf,
        0,
        Pointer(Arguments));
    WinCheck(I > 0);
    try
        SetString(Result, Buf, I);
    {$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
    finally LocalFree(HLOCAL(Buf)) end;
    {$IFDEF FPC}{$POP}{$ENDIF}
end;


function WideStringHelper.ToMultiByte;
var
    Len: Integer;
begin
    {$IFDEF FPC}AnsiStringSetLength{$ELSE}System.SetLength{$ENDIF}(Result, Self.Length);
    if Result.Length = 0 then Exit;

    Len := WideCharToMultiByte(
        CP_UTF8,
        0,
        PWideChar(Self), Self.Length,
        PAnsiChar(Result), Result.Length,
        nil, nil);
    WinCheck(Len > 0);
    {$IFDEF FPC}AnsiStringSetLength{$ELSE}System.SetLength{$ENDIF}(Result, Len);
end;


function WideStringHelper.LowerCase;
var
    I: Integer;
    C: WideChar;
begin
    {$IFDEF FPC}WideStringSetLength{$ELSE}System.SetLength{$ENDIF}(Result, Self.Length);
    for I := Low(Self) to High(Self) do
    begin
        C := Self[I];
        {$IFNDEF FPC}{$WARN WIDECHAR_REDUCED OFF}{$ENDIF}
        if C in ['A'..'Z'] then
            {$IFDEF FPC}{$PUSH}{$WARNINGS OFF}{$HINTS OFF}{$ENDIF}
            WORD(C) := LOWORD(DWORD(CharLowerW(PWideChar(C))));
            {$IFDEF FPC}{$POP}{$ENDIF}
        Result[I] := C;
    end;
end;


function WideStringHelper.Equals;
begin
    Result := lstrcmpiW(PWideChar(Self), PWideChar(Str)) = 0;
end;


function WideStringHelper.StartsWith;
begin
    Result := SubStringAt(1, Str);
end;


function WideStringHelper.SubStringAt;
begin
    Assert(SubString.Length > 0, 'Invalid text');
    if Offset < 1 then Offset := 1;  // Delphi-ben a string-ek also indexe 1...
    Result :=
      (SubString.Length + Pred(Offset) <= High(Self)) and
      (CompareStringW(0, DWORD($00000010) {ignore case}, PWideChar(Self) + Pred(Offset), SubString.Length, PWideChar(SubString), SubString.Length) = 2)
end;


function WideStringHelper.Length;
begin
    Result := {$IFDEF FPC}WideStringLength{$ELSE}System.Length{$ENDIF}(Self);
end;


procedure WideStringHelper.SetLength;
begin
    {$IFDEF FPC}WideStringSetLength{$ELSE}System.SetLength{$ENDIF}(Self, NewLength);
end;


function WideStringHelper.IndexOf;
var
    P: PWideChar;
begin
    if StartIndex > Self.Length then Exit(0);

    if First then P := StrChrIW(@Self[StartIndex], What)
    else P := StrRChrIW(@Self[StartIndex], nil, What);

    if P = nil then Result := 0
    {$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
    else Result := Succ(UIntPtr(P) - UIntPtr(PWideChar(Self)));
    {$IFDEF FPC}{$POP}{$ENDIF}
end;
{$ENDREGION}


{$REGION WideCharHelper}
function WideCharHelper.IsSpace;
var
    CharType: WORD;
begin
    WinCheck(GetStringTypeW(CT_CTYPE1, @Self, 1, @CharType));
    Result := BOOL(CharType and C1_SPACE);
end;
{$ENDREGION}


{$REGION TWideStringMarshaller}
constructor TWideStringMarshaller.Create;
begin
    FValue := S;
end;


function TWideStringMarshaller.GetValue;
begin
    Result := PWideChar(FValue);
end;
{$ENDREGION}


{$REGION TStringBuilder}
constructor TStringBuilder.Create(InitialSize: Integer);
begin
    Length    := InitialSize;
    FPosition := 0;
end;


procedure TStringBuilder.SetLength;
begin
    //
    // Ha az uj hossz kissebb az aktualis hossznal, akkkor
    // csak a poziciot allitjuk at.
    //

    if NewLength <= FPosition then FPosition := NewLength

    //
    // Kulonben a pozicio marad, a de a tenyleges hosszt meg-
    // noveljuk.
    //

    else FBuffer.SetLength(NewLength);
end;


procedure TStringBuilder.Append(const p: PWideChar; Len: Integer);
var
    Required: Integer;
begin
    if Len < 0 then Len := lstrlenW(P);

    Required := FPosition {Eddig hany darab volt} + Len {Hany uj darab lesz};
    if FBuffer.Length < Required then Length := Required * 2;

    Move(p^, (PWideChar(FBuffer) + FPosition)^, Len * SizeOf(WideChar));
    FPosition := Required;
end;


procedure TStringBuilder.Append(const p: WideString);
begin
    Append(PWideChar(p), p.Length);
end;


function TStringBuilder.ToString;
begin
    Result := FBuffer.SubString(1, FPosition {Ennyi elem van});
end;


function TStringBuilder.ToOleString;
begin
   Result := SysAllocStringLen(PWideChar(FBuffer), FPosition)
end;


function TStringBuilder.GetChar;
begin
    Assert((Index > 0) and (Index <= Position));
    Result := FBuffer[Index];
end;


function TStringBuilder.AccessData;
begin
    Result := PWideChar(FBuffer);
end;
{$ENDREGION}


end.
