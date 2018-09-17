library {$IFDEF CPU64}libjson64{$ELSE}libjson32{$ENDIF};

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

