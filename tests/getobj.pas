unit getobj;

{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}

interface

uses
    json.types;


function GetObject(const CLSID: TGUID; const CtorParams: TConstructorParams): IUnknown; safecall;


implementation


function GetObject; external 'libjson';


end.

