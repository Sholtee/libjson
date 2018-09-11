unit jsonobjecttest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}
{$H+}


interface


uses
    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF},

    json.object_;


type
    ExpandoObjectTests = class sealed(TTestCase)
    protected
        FObj: OleVariant;
        procedure SetUp; override;
        procedure TearDown; override;
        procedure NonExistingProperty;
        procedure CreateCircularReference;
    published
        procedure BasicTest;
        procedure CircularReferenceTest;
    end;


implementation


uses
    generic.containers, Variants, ComObj;


procedure ExpandoObjectTests.SetUp;
begin
    TVarData(FObj) := TExpandoObject.Create.AsVariant;

    CheckEquals(varDispatch, VarType(FObj));
    {$IFDEF FPC}
    Check(IUnknown(FObj) is IExpandoObject);
    {$ENDIF}
end;


procedure ExpandoObjectTests.TearDown;
begin
    // A "TVarData(FObj) :=" kifejezes miatt az automatikus
    // felszabaditas nem megy...
    FObj := NULL;
end;


procedure ExpandoObjectTests.NonExistingProperty;
var
    I: Integer;
begin
    I := FObj.NonExistingProperty;
    Check(I = 0);  // Csak h ne legyen hint
end;


procedure ExpandoObjectTests.BasicTest;
var
    I: Integer;
    V: TPair<TVarData>;
begin
    FObj.Property1 := 'XYZ';
    FObj.Property2 := Integer(1986);

    CheckEquals(FObj.Property1, 'XYZ');
    CheckEquals(FObj.Property1, 'XYZ', 'Property accessible only once'); // Megegyszer ugyanazt...
    CheckEquals(FObj.Property2,  1986);

    CheckException(NonExistingProperty, EOleSysError);

    I := 0;
    for V in IUnknown(FObj) as IExpandoObject do
    begin
        Check((V.Name = 'Property1') or (V.Name = 'Property2'));
        Inc(I);
    end;
    CheckEquals(2, I);
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
