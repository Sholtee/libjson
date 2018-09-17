# LibJSON

A lightweight, native (Win32/64) JSON reader/writer library, written in Object Pascal. 

## API

Here you can see the set of methods and types related to LibJSON. Note that the following declarations can easily be translated to C header.

```pas
{$A+} // record alignment on 4 byte boundaries
{$Z4} // enum size is 4 bytes

interface

uses JwaWinType;

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
        // function ParseValue([in] AString: PPWideChar; [out] Ret: PVARIANT): HRESULT; stdcall;
        function ParseValue(const {byRef} AString: WideString): OleVariant; safecall;
    end;

    IJsonWriter = interface
        ['{CA687B3B-C016-4DC4-9330-E1FB943F00CC}']
        function Write(const {byRef} AData: OleVariant): WideString; safecall;
        function CreateJsonObject: OleVariant; safecall;
    end;

    TFormatOption  = (foSingleLineArray, foSingleLineObject, foDoNotQuoteMembers, foMax {UNUSED});
    TFormatOptions = Set of TFormatOption;

// function GetObject([IN] CLSID: PGUID; [IN] CtorParams: PConstructorParams; [out] Ret: PIUnknown): HRESULT; stdcall;
function GetObject(const {byRef} CLSID: TGUID; const {byRef} CtorParams: TConstructorParams): IUnknown; safecall;

implementation

function GetObject; external 'libjson';
```
 
## Basic example
 
Reading a JSON string:

```pas
const
    CtorParams: TConstructorParams =
    (
        CancellationToken: 0; // not null only in multithreaded environments
        MaxDepth:          25;
        Strict_:           False;
    );
	
var
    Reader: IJsonReader;
    RetVal: OleVariant;
	
begin
    Reader := GetObject(IJsonReader, CtorParams) as IJsonReader;
	
    // Under the hood RetVal is an expando object wrapped into IDispatch
    RetVal := Reader.ParseValue('{str: "val", int: 3, obj: {field: "dummy"}}');
	
    // Accessing property names is case insensitive so RetVal.Str would be the same
    DebugMsg(RetVal.str); // will print "val"
    DebugMsg(RetVal.int); // will print "3"
    DebugMsg(RetVal.obj.field); // will print "dummy"

    DebugMsg(RetVal.obj.invalid); // will throw an exception
end;	
``` 
 
Writing a JSON string:

```pas
const
    CtorParams: TConstructorParams =
    (
        CancellationToken: 0;
        MaxDepth:          25;
        FormatOptions:     0;
    );
	
var
    Writer: IJsonWriter;
    Obj: OleVariant;
	Json: PWideChar;
	
begin
    Writer := GetObject(IJsonWriter, CtorParams) as IJsonWriter;
	
    // The following line creates an empty expando object wrapped into IDispatch
    Obj := Writer.CreateJsonObject;
	
	// Storing simple value
    Obj.Str := 'val'; 

	// Storing complex value
    Obj.AnotherObj := Writer.CreateJsonObject; // Arrays can be created by the standard OLE way (SafeArrayCreate(), etc.)
    Obj.AnotherObj.Int := 1986;

    // Removing a property
    Obj.PropertyToDelete := 10;
    Obj.PropertyToDelete := UNASSIGNED; // varEmpty
	
	Json := Writer.Write(Obj); // The returned pointer is valid until the next Write() call 	
    DebugMsg(JSon); // will print "{Str: "val", AnotherObj: {Int: 1986}}"
end;	
```

## Download

You can download the (64bit - FPC) compiled version of the library [here](https://github.com/Sholtee/libjson/releases/download/v0.0.1.10/libjson.dll).

## License

MIT