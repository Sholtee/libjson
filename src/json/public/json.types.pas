{*******************************************************************************

Author: Denes Solti

Unit:
    json.types.pas

Abstract:
    Public types.

History:
    2018.09.11: Created (Denes Solti)

*******************************************************************************}
unit json.types;


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
            0: (FormatOptions: DWORD); // TFormatOptions
            1: (Strict_: BOOL)
    end;


    IJsonReader = interface
        ['{B25495C9-7DF5-4098-803C-1078AD9DE596}']
        function ParseValue(const AString: WideString): TVarData; safecall;
    end;

    IJsonWriter = interface
        ['{CA687B3B-C016-4DC4-9330-E1FB943F00CC}']
        function Write(const AData: TVarData): PWideChar; safecall;
        function CreateJsonObject: TVarData; safecall;
    end;


    TFormatOption  = (foSingleLineArray, foSingleLineObject, foDoNotQuoteMembers, foMax {UNUSED});
    TFormatOptions = Set of TFormatOption;


implementation
end.
