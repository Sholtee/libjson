unit getobj;

{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}

{$A+} // record alignment on 4 byte boundaries
{$Z4} // enum size is 4 bytes

interface

uses JwaWinType;

type
    TConstructorParams = record
        CancellationToken: HANDLE;
        MaxDepth: DWORD;
        case INT of
            0: (FormatOptions: DWORD);
            1: (Strict_: BOOL)
    end;

    IJsonReader = interface
        ['{B25495C9-7DF5-4098-803C-1078AD9DE596}']
        function ParseValue(const AString: WideString): OleVariant; safecall;
    end;

    IJsonWriter = interface
        ['{CA687B3B-C016-4DC4-9330-E1FB943F00CC}']
        function Write(const AData: OleVariant): WideString; safecall;
        function CreateJsonObject: OleVariant; safecall;
    end;

    IKeySet = interface
        ['{209B7F20-DF44-4BD6-B1B1-19B2DED36763}']
        function GetKeys: OleVariant; safecall;
    end;

    TFormatOption  = (foSingleLineArray, foSingleLineObject, foDoNotQuoteMembers, foMax);
    TFormatOptions = Set of TFormatOption;


function GetObject(const CLSID: TGUID; const CtorParams: TConstructorParams): IUnknown; safecall;


implementation


function GetObject; external 'libjson' + {$IFDEF CPU64}'64'{$ELSE}'32'{$ENDIF};


end.

