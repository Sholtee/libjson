unit jsonobjecttest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF};


type
    ExpandoObjectTests = class sealed(TTestCase)
    private
        FObj: OleVariant;
        procedure NonExistingProperty;
        procedure CreateCircularReference;
        class function CreateExpandoObject: OleVariant;
    protected // csak h ne dumaljon a fordito
        procedure SetUp; override;
    published
        procedure BasicTest;
        procedure EnumeratorTest;
        procedure RemovingPropertyTest;
        procedure CircularReferenceTest;
    end;


implementation


uses
    generic.containers, Variants, ComObj,

    json.object_, json.types, exports_;


class function ExpandoObjectTests.CreateExpandoObject;
    function CreateInstance(const ClsId: TGuid): IUnknown;
    const
        CtorParams: TConstructorParams =
        (
            CancellationToken: 0;
            MaxDepth:          25;
            FormatOptions:     0;
        );
    begin
        OleCheck(GetObject(ClsId, CtorParams, Result));
    end;
begin
    TVarData(Result) := (CreateInstance(IJsonWriter) as IJsonWriter).CreateJsonObject;
end;

procedure ExpandoObjectTests.SetUp;
begin
    FObj := CreateExpandoObject;

    CheckEquals(varDispatch, VarType(FObj));
    {$IFDEF FPC}
    Check(IDispatch(FObj) is IExpandoObject);
    {$ENDIF}
end;


procedure ExpandoObjectTests.NonExistingProperty;
var
    I: Integer;
begin
    I := FObj.Property2;
    Check(I = 0);  // Csak h ne legyen hint
end;


procedure ExpandoObjectTests.BasicTest;
begin
    FObj.Property1 := 'XYZ';
    FObj.Property2 := Integer(1986);  // cast azert h FPC alatt is fussanak a tesztek
    FObj.Property3 := CreateExpandoObject;
    FObj.Property3.Property1 := Integer(10);

    CheckEquals(FObj.Property1, 'XYZ');
    CheckEquals(FObj.Property1, 'XYZ', 'Property accessible only once'); // Megegyszer ugyanazt...
    CheckEquals(FObj.Property2,  1986);
    CheckEquals(FObj.Property3.Property1, 10);
end;


procedure ExpandoObjectTests.EnumeratorTest;
var
    V: TPair<TVarData>;
    Keys: TAppendable<WideString>;
begin
    FObj.Property1 := 'XYZ';
    FObj.Property2 := Integer(1986);

    Keys := TAppendable<WideString>.Create;
    for V in IUnknown(FObj) as IExpandoObject do
    begin
        Keys.Append(V.Name);
    end;

    CheckEquals(Keys.Count, 2);
    Check(Keys[0] <> Keys[1]);
    Check((Keys[0] = 'Property1') or (Keys[0] = 'Property2'));
    Check((Keys[1] = 'Property1') or (Keys[1] = 'Property2'))
end;


procedure ExpandoObjectTests.RemovingPropertyTest;
begin
    FObj.Property1 := 'XYZ';
    FObj.Property2 := Integer(1986);

    CheckEquals(FObj.Property1, 'XYZ');
    CheckEquals(FObj.Property2,  1986);

    FObj.Property2 := UNASSIGNED; // delete
    CheckException(NonExistingProperty, EOleSysError);

    CheckEquals(FObj.Property1, 'XYZ');

    FObj.Property2 := Integer(5);
    CheckEquals(FObj.Property2, 5);
end;


procedure ExpandoObjectTests.CreateCircularReference;
begin
    FObj.SomeProperty := FObj;
end;


procedure ExpandoObjectTests.CircularReferenceTest;
begin
    CheckException(CreateCircularReference, EOleSysError);
end;


begin
{$IFDEF FPC}
    RegisterTests([ExpandoObjectTests]);
{$ELSE}
    RegisterTest(ExpandoObjectTests.Suite);
{$ENDIF}
end.
