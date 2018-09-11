{*******************************************************************************

(c) 2015 Denes Solti

Unit:
    dynamictest.pas

Abstract:
    Dinamikus tesztek.

History:
    2015.01.12: Letrehozva (Denes Solti)

*******************************************************************************}
unit dynamictest;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}


interface


uses
    {$IFDEF FPC}fpcunit, testregistry{$ELSE}TestFramework{$ENDIF};


type
    TDynamicTest = class abstract(TTestCase)
    {$IFDEF FPC}
    private
        FTestMethod: String;
    {$ENDIF}
    public
        class procedure UnitTests(const Instances: Array of TDynamicTest);
        {$IFDEF FPC}
        procedure SetUp; override;
        {$ENDIF}
        constructor Create(const TestMethod, Id: String); overload;
        constructor Create(const TestMethod: String; Id: Integer); overload;
    end;


implementation


uses
    SysUtils;


constructor TDynamicTest.Create(const TestMethod, Id: String);
begin
    inherited Create {$IFNDEF FPC}(TestMethod {Leteznie kell a metodusnak}){$ENDIF};
    {$IFNDEF FPC}FTestName{$ELSE}TestName{$ENDIF} := Format('%s(%s)', [TestMethod, Id]);
    {$IFDEF FPC}FTestMethod := TestMethod;{$ENDIF}
end;


constructor TDynamicTest.Create(const TestMethod: string; Id: Integer);
begin
    Create(TestMethod, IntToStr(Id));
end;


{$IFDEF FPC}
procedure TDynamicTest.SetUp;
begin
    TestName := FTestMethod;  // kibaszott nagy HACK
end;
{$ENDIF}


class procedure TDynamicTest.UnitTests;
var
    I: TDynamicTest;
    Suite: {$IFNDEF FPC}ITestSuite{$ELSE}TTestSuite{$ENDIF};
begin
    Suite := TTestSuite.Create(ClassName);
    for I in Instances do Suite.AddTest(I);
{$IFDEF FPC}
    GetTestRegistry.AddTest(Suite);
{$ELSE}
    RegisterTest(Suite);
{$ENDIF}
end;


end.
