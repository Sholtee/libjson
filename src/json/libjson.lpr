library libjson;

{$MODE OBJFPC}
{$H+}

{$R *.res}

uses
    {$IFOPT D+}
    heaptrc,  // Memory leaking check
    {$ENDIF}

    exports_;

exports
    GetObject;

end.

