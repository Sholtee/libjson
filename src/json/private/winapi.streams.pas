{*******************************************************************************
*    Missing Stream API Declarations
*
*    Author: Denes Solti
*******************************************************************************}
unit winapi.streams;

{$ifdef FPC}
    {$mode delphi}
{$endif}
{$H+}

interface

uses
    JwaActiveX, JwaWinType;


////////////////////////////////////////////////////////////////////////////////
const                                                                         //
    STGM_CREATE = $00001000;                                                  //
    STGM_WRITE	= $00000001;                                                  //
                                                                              //
                                                                              //
function CreateStreamOnHGlobal(hGlobal: HGLOBAL; DeleteOnRelease: BOOL;       //
    out Stream: IStream): HRESULT; stdcall;                                   //
                                                                              //
function GetHGlobalFromStream(pstm: IStream; out phglobal: HGLOBAL            //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SHCreateStreamOnFileW(pszFile: PWideChar; dwMode: DWORD;             //
    out ppSt: IStream): HRESULT; stdcall;                                     //
////////////////////////////////////////////////////////////////////////////////

implementation


function CreateStreamOnHGlobal; external 'ole32.dll';
function GetHGlobalFromStream;  external 'ole32.dll';
function SHCreateStreamOnFileW; external 'shlwapi.dll';

end.

