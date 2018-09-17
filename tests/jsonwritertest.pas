unit jsonwritertest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF},

    variants,

    getobj;


type
    JsonWriterTests = class(TTestCase)
    private
        FReader: IJsonReader;
        FWriter: IJsonWriter;
    public
        procedure AfterConstruction; override;
    published
        procedure ReadWriteRead;
    end;


implementation

uses
    comobj;


procedure JsonWriterTests.AfterConstruction;
    function CreateInstance(const ClsId: TGuid): IUnknown;
    const
        CtorParams: TConstructorParams =
        (
            CancellationToken: 0;
            MaxDepth:          25;
            FormatOptions:     0; // Strict_: False
        );
    begin
        Result := GetObject(ClsId, CtorParams);
    end;

begin
    inherited;
    FReader := CreateInstance(IJsonReader) as IJsonReader;
    FWriter := CreateInstance(IJsonWriter) as IJsonWriter;
end;


procedure JsonWriterTests.ReadWriteRead;
const
    DefJson =
        '{'                                          + sLineBreak +
        '    "glossary": {'                          + sLineBreak +
        '        "title": "Solti Dénes",'            + sLineBreak +
        '        "GlossDiv": {'                      + sLineBreak +
        '            "title": "S",'                  + sLineBreak +
        '            "GlossList": {'                 + sLineBreak +
        '                "GlossEntry": {'            + sLineBreak +
        '                    "ID": "SGML",'          + sLineBreak +
        '                    "SortAs": "SGML",'      + sLineBreak +
        '                    "GlossTerm": "Standard Generalized Markup Language",' + sLineBreak +
        '                    "Acronym": "SGML",'               + sLineBreak +
        '                    "Abbrev": "ISO 8879:1986",'       + sLineBreak +
        '                    "GlossDef": {'                    + sLineBreak +
        '                        "para": "A meta-markup language, used to create markup languages such as DocBook.",' + sLineBreak +
        '                        "Values": [2, 1.5]' + sLineBreak +
        '                    },'                     + sLineBreak +
        '                    "GlossSee": "markup"'   + sLineBreak +
        '                }'                          + sLineBreak +
        '            }'                              + sLineBreak +
        '        }'                                  + sLineBreak +
        '    }'                                      + sLineBreak +
        '}';
var
    StringToParse: WideString;
    Result:        OleVariant;
    I:             Byte;
begin
    StringToParse := DefJson;
    I := 0;
    repeat
        Inc(I);
        Result := UNASSIGNED; // Clear last value
        Result := FReader.ParseValue(PWideChar(StringToParse));

        CheckEquals(WideString('Solti Dénes'), Result.glossary.title); // Unicode
        CheckEquals(2, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [0])); // Array, int
        CheckEquals(1.5, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [1])); // Array, float

        if I > 1 then Break;

        StringToParse := FWriter.Write(Result);
    until False;
end;


begin
{$IFDEF FPC}
    RegisterTests([JsonWriterTests]);
{$ELSE}
    RegisterTest(JsonWriterTests.Suite);
{$ENDIF}
end.
