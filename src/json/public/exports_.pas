{*******************************************************************************

(c) 2014 Denes Solti

Unit:
    exports_.pas

Abstract:
    Publikus metodusok.

History:
    2014.12.30: Letrehozva (Denes Solti)
    2016.01.29: Felulvizsgalva (Denes Solti)

*******************************************************************************}
unit exports_;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$A+} // record alignment on 4 byte boundaries
{$Z4} // enum size is 4 bytes


interface


uses
    JwaWinType;


type
    TConstructorParams = record
        CancellationToken: HANDLE;
        MaxDepth: DWORD;
        case INT of
            0: (FormatOptions: DWORD);
            1: (Strict_: BOOL)
    end;


function GetObject(const CLSID: TGUID; const CtorParams: TConstructorParams; out Obj: IUnknown): HRESULT; stdcall;


implementation


uses
    JwaWinError,

    json.writer, json.reader;


{$IFDEF FPC}
function RtlCompareMemory(const Source1, Source2; Length: SIZE_T): SIZE_T; stdcall; external 'ntdll.dll';
{$ENDIF}


function GetFmtOpts(Val: Cardinal): TFormatOptions;
{$IFNDEF FPC}
    {$IF Ord(foMax) > 31}
        {$ERROR WTF}
    {$IFEND}
{$ENDIF}
var
    R: TFormatOptions absolute Val;
begin
    Result := R;
end;


function GetObject;
begin
    try
        if
            {$IFDEF FPC}
            RtlCompareMemory(CLSID, TGUID(IJsonReader), SizeOf(TGUID)) = SizeOf(TGUID)
            {$ELSE}
            CLSID = TGUID(IJsonReader)
            {$ENDIF} then
            Obj := TJsonReader.Create(
                CtorParams.Strict_,
                CtorParams.MaxDepth,
                CtorParams.CancellationToken)
        else if
            {$IFDEF FPC}
            RtlCompareMemory(CLSID, TGUID(IJsonWriter), SizeOf(TGUID)) = SizeOf(TGUID)
            {$ELSE}
            CLSID = TGUID(IJsonWriter)
            {$ENDIF} then
            Obj := TJsonWriter.Create(
                GetFmtOpts(CtorParams.FormatOptions),
                CtorParams.MaxDepth,
                CtorParams.CancellationToken)
        else
            Exit(E_INVALIDARG);

        Result := S_OK;
    except
        Result := E_UNEXPECTED;
    end;
end;


end.
