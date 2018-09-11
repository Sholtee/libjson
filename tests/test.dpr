program test;

{$R *.res}

uses
  Vcl.Forms,
  TestFramework,
  GuiTestRunner,
  jsonobjecttest in 'jsonobjecttest.pas',
  jsonreadertest in 'jsonreadertest.pas',
  jsonwritertest in 'jsonwritertest.pas';

begin
    ReportMemoryLeaksOnShutdown := True;
    Application.Initialize;
    Application.Title := 'libjson Tests';
    GUITestRunner.RunRegisteredTests;
end.
