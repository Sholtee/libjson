unit jsonwritertest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF},

    variants,

    json.reader, json.writer;


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


procedure JsonWriterTests.AfterConstruction;
begin
    inherited;
    FReader := TJsonReader.Create;
    FWriter := TJsonWriter.Create;
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
        Result := NULL; // Clear last value
        TVarData(Result) := FReader.ParseValue(PWideChar(StringToParse));

        CheckEquals(WideString('Solti Dénes'), Result.glossary.title); // Unicode
        CheckEquals(2, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [0])); // Array, int
        CheckEquals(1.5, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [1])); // Array, float

        if I > 1 then Break;

        StringToParse := FWriter.Write(TVarData(Result));
    until False;
end;


begin
{$IFDEF FPC}
    RegisterTests([JsonWriterTests]);
{$ELSE}
    RegisterTest(JsonWriterTests.Suite);
{$ENDIF}
end.
