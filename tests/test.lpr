program test;

{$mode objfpc}{$H+}

uses
    Forms, Interfaces,
    GuiTestRunner, fpcunittestrunner, fpcunit,

    getobj in 'getobj.pas',

    jsonobjecttest in 'jsonobjecttest.pas',
    jsonreadertest in 'jsonreadertest.pas',
    jsonwritertest in 'jsonwritertest.pas';


{$R *.res}

begin
    Application.Initialize;
    Application.CreateForm(TGuiTestRunner, TestRunner);
    Application.Run;
end.

