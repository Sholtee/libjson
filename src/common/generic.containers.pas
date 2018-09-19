{*******************************************************************************

Author: Denes Solti

Unit:
    generic.containers.pas

Abstract:
    Containers.

History:
    2014.11.01: Created (Denes Solti)
    2014.12.14: TAppendable<T> (Denes Solti)
    2015.02.08: Case insensitive name-value collection (Denes Solti)
    2018.09.19: IEnumerable<T>, IEnumerator<T>, INameValueCollection<T>, IAppendable<T> (Denes Solti)

*******************************************************************************}
unit generic.containers;


{$IFDEF FPC}
    {$MODE DELPHI}
    {$DEFINE ENUMERATOR_HACK}
{$ENDIF}


interface


type
{$IFDEF FPC}
    TArray<T> = array of T;
{$ENDIF}


    TNameValuePair<T> = record
        Name: WideString;
        Value: T;
    end;


    IEnumerator<T> = interface
        function GetCurrent: T;
        function MoveNext: Boolean;
        property Current: T read GetCurrent;
    end;


    IEnumerable<T> = interface
        function GetEnumerator: IEnumerator<T>;
    end;


    INameValueCollection<T> = interface{$IFNDEF ENUMERATOR_HACK}(IEnumerable<TNameValuePair<T>>){$ENDIF}
        function Add(const Name: WideString; const Value: T): Boolean;
        function Get(const Name: WideString; out Value: T): Boolean;
        function Remove(const Name: WideString): Boolean;
        function Contains(const Name: WideString): Boolean;
        function GetCount: Integer;
        procedure Clear;
        property Count: Integer read GetCount;
    end;


    TCaseSensitiveNameValueCollection<T> = class(TInterfacedObject, INameValueCollection<T>)
    protected const
        INITIAL_BUCKET_COUNT = 4;
    protected type
        PIEntry = ^IEntry;
        IEntry = interface
           function KVP: TNameValuePair<T>;
           function Next: PIEntry;
        end;
        TEntry = class sealed(TInterfacedObject, IEntry)
        private
            FKVP:  TNameValuePair<T>;
            FNext: IEntry;
            function KVP: TNameValuePair<T>;
            function Next: PIEntry;
        public
            constructor Create(const AName: WideString; const AData: T);
        end;
    public type
        TEnumerator = class sealed(TInterfacedObject{$IFNDEF ENUMERATOR_HACK}, IEnumerator<TNameValuePair<T>>{$ENDIF})
        private
            FBuckets: TArray<IEntry>; // NEM masolat...
            FIndex:   Integer;
            FCurrent: IEntry;
            function GetCurrent: TNameValuePair<T>;
        public
            constructor Create(const ABuckets: TArray<IEntry>);
            function MoveNext: Boolean;
            property Current: TNameValuePair<T> read GetCurrent;
        end;
    strict private
        //
        // Bucket (vodor) az IEntry-k egy halmaza mely az FBuckets
        // egy indexe alol erheto el.
        //

        FBuckets: TArray<IEntry>;
        FCount:   Integer;
        procedure Grow;
    protected
        procedure SetBucketCount(BucketCount: Cardinal);
        procedure ReHash(BucketCount: Cardinal);
        function Hash(const Str: WideString): Cardinal; virtual;
        function Find(const Name: WideString): PIEntry;
        function GetCount: Integer;
        property Buckets: TArray<IEntry> read FBuckets;
    public
        constructor Create;
        { IEnumerable<TNameValuePair<T>> }
        function GetEnumerator: {$IFNDEF ENUMERATOR_HACK}IEnumerator<TNameValuePair<T>>{$ELSE}TEnumerator{$ENDIF};
        { INameValueCollection<T> }
        function Add(const Name: WideString; const Value: T): Boolean;
        function Get(const Name: WideString; out Data: T): Boolean;
        function Remove(const Name: WideString): Boolean;
        function Contains(const Name: WideString): Boolean;
        procedure Clear;
    public
        property Count: Integer read GetCount;
    end;


    TCaseInsensitiveNameValueCollection<T> = class sealed(TCaseSensitiveNameValueCollection<T>)
    protected
        function Hash(const Str: WideString): Cardinal; override;
    end;


    IAppendable<T> = interface
        procedure Append(const Val: T);
        procedure Clean;
        function GetResult: TArray<T>;
        function GetCount: Integer;
        function GetItem(Index: Integer): T;
        procedure SetItem(Index: Integer; Val: T);

        property Result: TArray<T> read GetResult;
        property Count: Integer read GetCount;
        property Items[Index: Integer]: T read GetItem write SetItem; default;
    end;


    TAppendable<T> = class(TInterfacedObject, IAppendable<T>)
    private
        FBuffer: TArray<T>;
        FCount:  Integer;
        { IAppendable }
        function GetResult: TArray<T>;
        function GetCount: Integer;
        function GetItem(Index: Integer): T;
        procedure SetItem(Index: Integer; Val: T);
    public
        procedure Append(const Val: T);
        procedure Clean;
        property Result: TArray<T> read GetResult;
        property Count: Integer read GetCount;
        property Items[Index: Integer]: T read GetItem write SetItem; default;
    end;


implementation


uses
    JwaWinError,

    system.error, system.strings;


{$REGION TEntry}
constructor TCaseSensitiveNameValueCollection<T>.TEntry.Create;
begin
    FKVP.Name := AName;
    FKVP.Value := AData;
end;


function TCaseSensitiveNameValueCollection<T>.TEntry.KVP;
begin
    Result := FKVP;
end;


function TCaseSensitiveNameValueCollection<T>.TEntry.Next;
begin
    Result := @FNext;
end;
{$ENDREGION}


{$REGION TCaseSensitiveNameValueCollection}
constructor TCaseSensitiveNameValueCollection<T>.Create;
begin
    inherited;
    SetBucketCount(INITIAL_BUCKET_COUNT);
end;


procedure TCaseSensitiveNameValueCollection<T>.ReHash;
var
    Tmp: TCaseSensitiveNameValueCollection<T>;
    I:   TNameValuePair<T>;
begin
    //
    // Ahelyett h in place szamolgatnank ujra a hash-eket,
    // egyszerubb ha letrehozunk egy uj hash tablat adott
    // tablamerettel, majd abba masoljuk az eddig felvett
    // elemeket.
    //

    Tmp := ClassType.Create as TCaseSensitiveNameValueCollection<T>; // Az aktualis tipust peldanyositjuk
    try
        Tmp.SetBucketCount(BucketCount);
        for I in Self do Tmp.Add(I.Name, I.Value);

        //
        // A regi tablat az ujra csereljuk.
        //

        FBuckets := Tmp.Buckets;
    finally
        Tmp.Free;
    end;
end;


procedure TCaseSensitiveNameValueCollection<T>.Grow;
var
    NewCap: Cardinal;
begin
    if Length(FBuckets) = 0 then NewCap := INITIAL_BUCKET_COUNT
    else NewCap := Length(FBuckets) * 2;

    ReHash(NewCap);
end;


function TCaseSensitiveNameValueCollection<T>.Hash;
var
    C: WideChar;
begin
    //
    // Hash kalkulacio.
    //

    Result := 0;
    for C in Str do
        {$Q-}
        Result := Cardinal(Integer(Result shl 5) - Integer(Result)) xor Ord(C);
        {$Q+}
    //
    // Ferjunk bele az oszlopok szamaba.
    //

    Result := Result mod Cardinal( Length(FBuckets) );
end;


function TCaseSensitiveNameValueCollection<T>.Find;
begin
    //
    // Ugras a nevhez tartozo hash oszlopanak elso elemere.
    //

    Result := @FBuckets[ Hash(Name) ];

    //
    // Linearisan keressuk meg a nevhez tartozo elemet, v
    // az utolso elem Next mezojet.
    //

    while Assigned(Result^) do
    begin
        if Result.KVP.Name.Equals(Name) then Exit;
        Result := Result.Next;
    end;
end;


function TCaseSensitiveNameValueCollection<T>.Contains;
begin
    Result := Assigned( Find(Name)^ );
end;


function TCaseSensitiveNameValueCollection<T>.Add;
var
    P: PIEntry;
begin
    //
    // Ha az elemek szama a tablanak maximum 75%-a legyen.
    //

    if FCount >= Length(FBuckets) shr 1 + Length(FBuckets) shr 2 {75%} then
        Grow;

    //
    // Ha adott nevvel nem letezik a nevhez tartozo hash
    // oszlopban elem akkor "P" az oszlop utolso elemenek
    // Next mezojere (v az oszlop fejere, ures oszlop ese-
    // ten) mutat, kuloben magara az elemre.
    //

    P := Find(Name);
    Result := not Assigned(P^);  // Volt elem mar ezzel a nevvel?

    if Result then
    begin
        P^ := TEntry.Create(Name, Value); // Torli a regi elemet (ha volt)
        Inc(FCount);
    end;
end;


function TCaseSensitiveNameValueCollection<T>.Get;
var
    Entry: IEntry;
begin
    Entry  := Find(Name)^;
    Result := Assigned(Entry);

    if Result then Data := Entry.KVP.Value;
end;


function TCaseSensitiveNameValueCollection<T>.Remove;
var
    Prev:  PIEntry;
    Entry: IEntry;  // Kell az automatikus felszabaditashoz
begin
    Prev   := Find(Name);
    Entry  := Prev^;
    Result := Assigned(Entry);

    if Result then
    begin
        //
        // Ha letezik elem adott nevvel akkor kivesszuk a lancolt
        // listabol (felulirjuk a kovetkezo elemmel).
        //

        Prev^ := Entry.Next^;
        Dec(FCount);
    end;
end;


procedure TCaseSensitiveNameValueCollection<T>.Clear;
begin
    SetBucketCount(0); // Torli a korabbi elemeket
    SetBucketCount(INITIAL_BUCKET_COUNT);
    FCount := 0;
end;


procedure TCaseSensitiveNameValueCollection<T>.SetBucketCount;
begin
    try
        SetLength(FBuckets, BucketCount);
    except
        ComError(E_OUTOFMEMORY);
    end;
end;


function TCaseSensitiveNameValueCollection<T>.GetEnumerator;
begin
    Result := TEnumerator.Create(FBuckets);
end;


function TCaseSensitiveNameValueCollection<T>.GetCount;
begin
    Result := FCount;
end;
{$ENDREGION}


{$REGION TEnumerator}
constructor TCaseSensitiveNameValueCollection<T>.TEnumerator.Create;
begin
    FBuckets := ABuckets;
end;


function TCaseSensitiveNameValueCollection<T>.TEnumerator.MoveNext;
begin
    repeat
        //
        // Mar egy elemen allunk. Van mellette masik?
        //

        if Assigned(FCurrent) then FCurrent := FCurrent.Next^

        //
        // Ugras a kovetkezo hash-re
        //

        else begin
            if FIndex = Length(FBuckets) then Exit(False);
            FCurrent := FBuckets[FIndex];
            Inc(FIndex);
        end;

        //
        // A kovetkezo meg bejaratlan elemen vagyunk.
        //

        if Assigned(FCurrent) then Exit(True);
    until False;
end;


function TCaseSensitiveNameValueCollection<T>.TEnumerator.GetCurrent;
begin
    Assert( Assigned(FCurrent) );

    Result := FCurrent.KVP;
end;
{$ENDREGION}


{$REGION TCaseInsensitiveNameValueCollection}
function TCaseInsensitiveNameValueCollection<T>.Hash;
begin
    Result := inherited Hash(Str.LowerCase);
end;
{$ENDREGION}


{$REGION TAppendable}
function TAppendable<T>.GetCount;
begin
    Result := FCount;
end;


procedure TAppendable<T>.Append;
var
    Delta: Integer;
begin
    if Length(FBuffer) = FCount then
    begin
        if FCount = 0 then Delta := 4 else Delta := Length(FBuffer) * 2;
        try
            SetLength(FBuffer, Delta);
        except
            ComError(E_OUTOFMEMORY);
        end;
    end;
    FBuffer[FCount] := Val;
    Inc(FCount);
end;


function TAppendable<T>.GetResult;
begin
    //
    // Meret korrekcio.
    //

    SetLength(FBuffer, FCount);
    Result := FBuffer; // NEM masolat...
end;


function TAppendable<T>.GetItem;
begin
    if ((Index < 0) or (Index > FCount -1)) then WinError(ERROR_BUFFER_OVERFLOW);
    Result := FBuffer[Index];
end;


procedure TAppendable<T>.SetItem;
begin
    if ((Index < 0) or (Index > FCount -1)) then WinError(ERROR_BUFFER_OVERFLOW);
    FBuffer[Index] := Val;
end;


procedure TAppendable<T>.Clean;
begin
    SetLength(FBuffer, 0);
    FCount := 0;
end;
{$ENDREGION}


end.

