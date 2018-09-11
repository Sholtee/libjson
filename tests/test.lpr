program test;

{$mode objfpc}{$H+}

uses
    heaptrc,  // Memory leaking check
    Forms, Interfaces,
    GuiTestRunner, fpcunittestrunner, fpcunit,

    jsonobjecttest in 'jsonobjecttest.pas',
    jsonreadertest in 'jsonreadertest.pas',
    jsonwritertest in 'jsonwritertest.pas';


{$R *.res}

begin
    Application.Initialize;
    Application.CreateForm(TGuiTestRunner, TestRunner);
    Application.Run;
end.

