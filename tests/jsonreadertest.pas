unit jsonreadertest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    ComObj,

    JwaWinError,

    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF},

    variants,

    getobj;


type
    JsonReaderTests = class sealed(TTestCase)
    const
        sJsonOrgExample1 =
            '{'                                          + sLineBreak +
            '    "glossary": {'                          + sLineBreak +
            '        "title": "example glossary",'       + sLineBreak +
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
    private
        FReader: IJsonReader;
    public
        procedure AfterConstruction; override;
    published
        procedure JsonOrgExample1;
        procedure JsonOrgExample2;
        procedure EmptyArray;
        procedure EmptyObject;
        procedure NonQuotedProperty;
        procedure UnicodeTest;
        procedure IntTest;
        procedure DepthCheckTest;
    end;


implementation


procedure JsonReaderTests.AfterConstruction;
const
    CtorParams: TConstructorParams =
    (
        CancellationToken: 0;
        MaxDepth:          25;
        Strict_:           False;
    );
begin
    inherited;
    FReader := GetObject(IJsonReader, CtorParams) as IJsonReader;
end;


procedure JsonReaderTests.JsonOrgExample1;
var
    Result: OleVariant;
begin
    Result := FReader.ParseValue(sJsonOrgExample1);
{
    CheckEquals(21, Rdr.Row);
    CheckEquals(1, Rdr.Column);
}
    CheckEquals('example glossary', Result.glossary.title);
    CheckEquals('S', Result.glossary.GlossDiv.title);
    CheckEquals('SGML', Result.glossary.GlossDiv.GlossList.GlossEntry.ID);
    CheckEquals('Standard Generalized Markup Language', Result.glossary.GlossDiv.GlossList.GlossEntry.GlossTerm);
    CheckEquals('A meta-markup language, used to create markup languages such as DocBook.', Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.para);
    CheckEquals(varArray or varVariant, VarType(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values));
    CheckEquals(2, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [0]));
    CheckEquals(1.5, VarArrayGet(Result.glossary.GlossDiv.GlossList.GlossEntry.GlossDef.Values, [1]));
    CheckEquals('markup', Result.glossary.GlossDiv.GlossList.GlossEntry.GlossSee);
end;


procedure JsonReaderTests.JsonOrgExample2;
var
    Result: OleVariant;

    procedure CheckArrayElement(I: Integer; const Id, Lbl: String);
    begin
        CheckEquals(Id, VarArrayGet(Result.menu.items, [I]).id);
        if Length(Lbl) > 0 then
            CheckEquals(Lbl, VarArrayGet(Result.menu.items, [I]).label_);
    end;

    procedure CheckArrayNullElement(I: Integer);
    begin
        CheckTrue(Variants.NULL = VarArrayGet(Result.menu.items, [I]));
    end;

begin
    Result := FReader.ParseValue(
      '{"menu": {'                                               + sLineBreak +
      '    "header": "SVG Viewer",'                              + sLineBreak +
      '    "items": ['                                           + sLineBreak +
      '        {"id": "Open"},'                                  + sLineBreak +
      '        {"id": "OpenNew", "label_": "Open New"},'          + sLineBreak +
      '        null,'                                            + sLineBreak +
      '        {"id": "ZoomIn", "label_": "Zoom In"},'            + sLineBreak +
      '        {"id": "ZoomOut", "label_": "Zoom Out"},'          + sLineBreak +
      '        {"id": "OriginalView", "label_": "Original View"},'+ sLineBreak +
      '        null,'                                            + sLineBreak +
      '        {"id": "Quality"},'                               + sLineBreak +
      '        {"id": "Pause"},'                                 + sLineBreak +
      '        {"id": "Mute"},'                                  + sLineBreak +
      '        null,'                                            + sLineBreak +
      '        {"id": "Find", "label_": "Find..."},'              + sLineBreak +
      '        {"id": "FindAgain", "label_": "Find Again"},'      + sLineBreak +
      '        {"id": "Copy"},'                                  + sLineBreak +
      '        {"id": "CopyAgain", "label_": "Copy Again"},'      + sLineBreak +
      '        {"id": "CopySVG", "label_": "Copy SVG"},'          + sLineBreak +
      '        {"id": "ViewSVG", "label_": "View SVG"},'          + sLineBreak +
      '        {"id": "ViewSource", "label_": "View Source"},'    + sLineBreak +
      '        {"id": "SaveAs", "label_": "Save As"},'            + sLineBreak +
      '        null,'                                            + sLineBreak +
      '        {"id": "Help"},'                                  + sLineBreak +
      '        {"id": "About", "label_": "About Adobe CVG Viewer..."}'+ sLineBreak +
      '    ]'                                                    + sLineBreak +
      '}}'
    );

    CheckEquals('SVG Viewer', Result.menu.header);
    CheckArrayElement(0, 'Open', '');
    CheckArrayElement(1, 'OpenNew', 'Open New');
    CheckArrayNullElement(2);
    CheckArrayElement(3, 'ZoomIn', 'Zoom In');
    CheckArrayElement(21, 'About', 'About Adobe CVG Viewer...');
end;


procedure JsonReaderTests.UnicodeTest;
    function GetString(const S: WideString): WideString;
    begin
        Result := OleVariant( FReader.ParseValue(S) );
    end;
begin
    CheckEquals(WideString('Solti Dénes'), GetString('"Solti D\u00E9nes"'));
    CheckEquals(WideString('é'), GetString('"\u00E9"'));
    CheckEquals(WideString('\é') + sLineBreak, GetString('"\\\u00E9\r\n"'));
end;


procedure JsonReaderTests.IntTest;
    function GetInt(const S: WideString): Integer;
    begin
        Result := OleVariant( FReader.ParseValue(S) );
    end;
begin
    CheckEquals(1986, GetInt('1986'));
    CheckEquals(-1986, GetInt('-1986'));
    CheckEquals(1986, GetInt('+1986'));
end;


procedure JsonReaderTests.NonQuotedProperty;
var
    Result: OleVariant;
begin
    Result := FReader.ParseValue(
      '{'                                 + sLineBreak +
      '    glossary: {'                   + sLineBreak +
      '        title: "example glossary"' + sLineBreak +
      '    }                            ' + sLineBreak +
      '}'
    );

    CheckEquals('example glossary', Result.glossary.title);
end;


procedure JsonReaderTests.EmptyArray;
var
    Result: OleVariant;
begin
    Result := FReader.ParseValue('[]');
    CheckEquals(0, VarArrayLowBound(Result, 1));
    CheckEquals(-1, VarArrayHighBound(Result, 1));
end;


procedure JsonReaderTests.EmptyObject;
var
    Keys: OleVariant;
begin
    Keys := (FReader.ParseValue('{}') as IKeySet).GetKeys;
    CheckEquals(0, VarArrayHighBound(Keys, 1));
end;


{$IFDEF FPC}{$PUSH}{$NOTES OFF}{$ENDIF}
procedure JSonReaderTests.DepthCheckTest;
const
    CtorParams: TConstructorParams =
    (
        CancellationToken: 0;
        MaxDepth:          6;
        Strict_:           False;
    );
var
    Result: OleVariant;
    TmpRdr: IJsonReader;
begin
    Result := FReader.ParseValue(sJsonOrgExample1); // Meg mennie kell
    try
        TmpRdr := GetObject(IJsonReader, CtorParams) as IJsonReader;

        TmpRdr.ParseValue(sJsonOrgExample1); // Mar nem mehet
        Check(False, 'No exception throwned');
    except on Ex: EOleSysError do
        CheckEquals(HRESULT_FROM_WIN32(ERROR_STACK_OVERFLOW), Ex.ErrorCode);
    end;
end;
{$IFDEF FPC}{$POP}{$ENDIF}


begin
{$IFDEF FPC}
    RegisterTests([JsonReaderTests]);
{$ELSE}
    RegisterTest(JsonReaderTests.Suite);
{$ENDIF}
end.
