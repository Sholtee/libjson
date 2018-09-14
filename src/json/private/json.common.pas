{*******************************************************************************

Author: Denes Solti

Unit:
    json.common.pas

Abstract:
    Common stuffs.

History:
    2016.01.28: Created (Denes Solti)

*******************************************************************************}
unit json.common;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}


interface


uses
    com.safeobject;


type
    TCancelable = class(TSafeObject)
    protected
        FCancellationToken: THandle;
        FCancelCounter:     Cardinal;
        procedure CheckCancelled;
    public
        constructor Create(ACancellationToken: THandle);
    end;


implementation


uses
    JwaWinBase, JwaWinError,

    system.error;


{$REGION TCancelable}
constructor TCancelable.Create;
begin
    inherited Create;
    FCancellationToken := ACancellationToken;
end;


procedure TCancelable.CheckCancelled;
var
    State: Cardinal;
begin
    if FCancellationToken = 0 then Exit;

    //
    // Tenylegesen csak minden 50. (vagy a 0.) hivasnal
    // vizsgaljuk meg h meg kell e szakitani a muvele-
    // tet (a WaitForSingleObject() sokaig tart).
    //

    if FCancelCounter mod 50 = 0 then
    begin
        State := WaitForSingleObject(FCancellationToken, 0);
        WinCheck(State <> WAIT_FAILED);

        if State = WAIT_OBJECT_0 then WinError(ERROR_CANCELLED);
    end;
    Inc(FCancelCounter);
end;
{$ENDREGION}


end.
