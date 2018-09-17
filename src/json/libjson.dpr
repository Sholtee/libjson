library libjson;

{$R *.res}

uses
    exports_;


exports
    GetObject;

begin
{$IFOPT D+}
    ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
end.
