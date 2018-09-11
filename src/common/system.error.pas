{*******************************************************************************

(c) 2014 Denes Solti

Unit:
    system.error.pas

Abstract:
    Hibak.

History:
    2014.10.21: Letrehozva (Denes Solti)

*******************************************************************************}
unit system.error;

{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}

interface


uses
    JwaWinBase, JwaWinNT, JwaWinType, JwaWinError;


type
    TErrorBase = class(TObject)
    protected
        FHResult: HRESULT;
        FMessage: WideString;
    public
        property Message: WideString read FMessage;
        property HResult: HRESULT read FHResult;
    end;


    TWinError = class sealed(TErrorBase)
    private
        FWinError: Cardinal;
    public
        constructor Create(ErrorCode: Cardinal);
        property Error: Cardinal read FWinError;
    end;


    TComError = class sealed(TErrorBase)
    public
        constructor Create(ErrorCode: HRESULT);
    end;


function ComCheck(ECode: HRESULT): HRESULT;

procedure ComError(ECode: HRESULT);

procedure WinError(ECode: DWORD);

procedure WinCheck(B: Boolean); overload;

procedure WinCheck(ECode: DWORD); overload;

function SysErrorMessage(ErrorCode: Integer): WideString;


implementation


{$REGION Errors}
constructor TWinError.Create(ErrorCode: Cardinal);
begin
    FHResult  := HRESULT_FROM_WIN32(ErrorCode);
    FWinError := ErrorCode;
    FMessage  := SysErrorMessage(ErrorCode);
end;


constructor TComError.Create(ErrorCode: HRESULT);
begin
    FHResult := ErrorCode;
    FMessage := SysErrorMessage(ErrorCode);
end;
{$ENDREGION}


{$REGION Tools}
procedure InternalRaiseComError(ECode: HRESULT {$IFNDEF FPC}; Addr: Pointer{$ENDIF});
begin
    raise TComError.Create(ECode) {$IFNDEF FPC}at Addr{$ENDIF};
end;


procedure ComError(ECode: HRESULT);
begin
    InternalRaiseComError(ECode{$IFNDEF FPC}, ReturnAddress{$ENDIF});
end;


function ComCheck(ECode: HRESULT): HRESULT;
begin
    if FAILED(ECode) then InternalRaiseComError(ECode{$IFNDEF FPC}, ReturnAddress{$ENDIF});
    Result := ECode;
end;


procedure InternalRaiseWinError(ECode: DWORD {$IFNDEF FPC}; Addr: Pointer{$ENDIF});
begin
    raise TWinError.Create(ECode) {$IFNDEF FPC}at Addr{$ENDIF};
end;


procedure WinError(ECode: DWORD);
begin
    InternalRaiseWinError(ECode {$IFNDEF FPC}, ReturnAddress{$ENDIF});
end;


procedure WinCheck(B: Boolean);
begin
    if not B then InternalRaiseWinError(GetLastError {$IFNDEF FPC}, ReturnAddress{$ENDIF});
end;


procedure WinCheck(ECode: DWORD);
begin
    if ECode <> NO_ERROR then InternalRaiseWinError(ECode {$IFNDEF FPC}, ReturnAddress{$ENDIF});
end;


function SysErrorMessage(ErrorCode: Integer): WideString;
var
    Len:  DWord;
    Buff: PWideChar;
begin
    Buff := nil;
    Len := FormatMessageW(
        FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER,
        nil,  // Modul
        ErrorCode,
        MakeLangID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        @Buff,// Buffer
        0,    // Length
        nil); // Args

    try
        SetString(Result, Buff, Len);
    finally
        {$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
        LocalFree( HLOCAL(Buff) );
        {$IFDEF FPC}{$POP}{$ENDIF}
    end;
end;
{$ENDREGION}


end.

