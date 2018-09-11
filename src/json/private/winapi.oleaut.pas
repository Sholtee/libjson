{*******************************************************************************
*    oleaut header
*
*    Author: Denes Solti
*******************************************************************************}
unit winapi.oleaut;

{$ifdef FPC}
    {$mode delphi}
{$endif}
{$H+}

interface


uses
    JwaWinBase, JwaActiveX, JwaWinType;


////////////////////////////////////////////////////////////////////////////////
//                        Missing API declarations                            //
const                                                                         //
    oleautlib = 'oleaut32.dll';                                               //
                                                                              //
function SafeArrayCreate(vt: tvartype; cdims: UINT;                           //
    var rgsabound: SAFEARRAYBOUND): Pointer; stdcall;                         //
                                                                              //
function SafeArrayRedim(psa: Pointer;                                         //
    var rgsabound: SAFEARRAYBOUND): HRESULT; stdcall;                         //
                                                                              //
function SafeArrayAccessData(psa: Pointer; out ppData: PVOID): HRESULT;       //
    stdcall;                                                                  //
                                                                              //
function SafeArrayGetElement(psa: Pointer; var ix: LONG; pv: PVOID            //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SafeArrayPutElement(psa: Pointer; var ix: LONG; const pv            //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SafeArrayDestroy(psa: Pointer): HRESULT; stdcall;                    //
                                                                              //
function SafeArrayUnaccessData(psa: Pointer): HRESULT; stdcall;               //
                                                                              //
function SafeArrayGetVartype(psa: Pointer; out vt: TVarType                   //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SafeArrayLock(psa: Pointer): HRESULT; stdcall;                       //
                                                                              //
function SafeArrayUnlock(psa: Pointer): HRESULT; stdcall;                     //
                                                                              //
function SafeArrayGetUBound(psa: Pointer; nDim: UINT; out UBound: LONG        //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SafeArrayGetLBound(psa: Pointer; nDim: UINT; out LBound: LONG        //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function SafeArrayGetDim(psa: Pointer): UINT; stdcall;                        //
                                                                              //
procedure VariantInit(out pvarg: tvardata); stdcall;                          //
                                                                              //
function VariantClear(var pvarg: tvardata): HRESULT; stdcall;                 //
                                                                              //
function VariantCopy(out pvargDest: tvardata; const pvargSrc: tvardata        //
    ): HRESULT; stdcall;                                                      //
                                                                              //
function VariantChangeType(out pDest: TVarData; const pSrc: TVarData;         //
    Flags: USHORT; VType: WORD): HRESULT; stdcall;                            //
                                                                              //
function SysAllocString(src: PWideChar): PWideChar; stdcall;                  //
                                                                              //
function SysAllocStringLen(src: PWideChar; ui: UINT): PWideChar; stdcall;     //
                                                                              //
procedure SysFreeString(sz: PWideChar); stdcall;                              //
                                                                              //
function SystemTimeToVariantTime(const sTime: SYSTEMTIME;                     //
    out vTime: TDateTime): BOOL; stdcall;                                     //
                                                                              //
function VariantTimeToSystemTime(vTime: TDateTime; out sTime: SYSTEMTIME      //
    ): BOOL; stdcall;                                                         //
////////////////////////////////////////////////////////////////////////////////



implementation

function SafeArrayCreate;         external oleautlib;
function SafeArrayAccessData;     external oleautlib;
function SafeArrayRedim;          external oleautlib;
function SafeArrayGetElement;     external oleautlib;
function SafeArrayPutElement;     external oleautlib;
function SafeArrayDestroy;        external oleautlib;
function SafeArrayUnaccessData;   external oleautlib;
function SafeArrayGetVartype;     external oleautlib;
function SafeArrayLock;           external oleautlib;
function SafeArrayUnlock;         external oleautlib;
function SafeArrayGetUBound;      external oleautlib;
function SafeArrayGetLBound;      external oleautlib;
function SafeArrayGetDim;         external oleautlib;
procedure VariantInit;            external oleautlib;
function VariantClear;            external oleautlib;
function VariantCopy;             external oleautlib;
function VariantChangeType;       external oleautlib;
function SysAllocString;          external oleautlib;
function SysAllocStringLen;       external oleautlib;
procedure SysFreeString;          external oleautlib;
function SystemTimeToVariantTime; external oleautlib;
function VariantTimeToSystemTime; external oleautlib;


end.

