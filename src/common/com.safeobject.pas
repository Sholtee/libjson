{*******************************************************************************

Author: Denes Solti

Unit:
    com.safeobject.pas

Abstract:
    COM objects base.

History:
    2014.11.01: Created (Denes Solti)

*******************************************************************************}
unit com.safeobject;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    system.error;


type
    TSafeObject = class(TInterfacedObject)
    public
        function SafeCallException(ExceptObj: TObject; Addr: Pointer): HRESULT; override; final;
    end;


implementation



{$IFDEF FPC}{$PUSH}{$HINTS OFF}{$ENDIF}
function TSafeObject.SafeCallException;
begin
    if not (ExceptObj is TErrorBase) then Result := E_UNEXPECTED
    else Result := TErrorBase(ExceptObj).HResult;
end;
{$IFDEF FPC}{$POP}{$ENDIF}


end.
