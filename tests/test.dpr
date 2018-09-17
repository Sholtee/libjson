program test;

{$R *.res}

uses
  Vcl.Forms,
  TestFramework,
  GuiTestRunner,

  getobj in 'getobj.pas',

  jsonobjecttest in 'jsonobjecttest.pas',
  jsonreadertest in 'jsonreadertest.pas',
  jsonwritertest in 'jsonwritertest.pas';

begin
    Application.Initialize;
    Application.Title := 'libjson Tests';
    GUITestRunner.RunRegisteredTests;
end.
