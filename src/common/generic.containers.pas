{*******************************************************************************

Author: Denes Solti

Unit:
    generic.containers.pas

Abstract:
    Containers.

History:
    2014.11.01: Created (Denes Solti)
    2014.12.14: TAppendable<T> (Denes Solti)
    2015.02.08: Case insensitive dictionary (Denes Solti)
    2016.07.17: Linked lists (Denes Solti)

*******************************************************************************}
unit generic.containers;


{$IFDEF FPC}
    {$MODE DELPHI}
{$ENDIF}


interface


type
{$IFDEF FPC}
    TArray<T> = array of T;
{$ENDIF}


    TPair<T> = record
        Name: WideString;
        Data: T;
    end;


    ///
    ///  Kis-nagybetu erzekeny szotar.
    ///
    TCustomNameValueCollection<T> = class
    protected const
        INITIAL_TABLE_SIZE = 4;
    protected type
        PIHashItem = ^IHashItem;
        IHashItem = interface
           function Name: WideString;
           function Data: T;
           function Next: PIHashItem;
        end;
        THashItem = class sealed(TInterfacedObject, IHashItem)
        private
            FName: WideString;
            FData: T;
            FNext: IHashItem;
            function Name: WideString;
            function Data: T;
            function Next: PIHashItem;
        public
            constructor Create(const AName: WideString; const AData: T);
        end;
    public type
        THashEnumerator = class sealed
        private
            FTable:   TArray<IHashItem>; // NEM masolat...
            FIndex:   Integer;
            FCurrent: IHashItem;
            function GetCurrent: TPair<T>;
        public
            constructor Create(const ATable: TArray<IHashItem>);
            function MoveNext: Boolean;
            property Current: TPair<T> read GetCurrent;
        end;
    strict private
        FTable: TArray<IHashItem>;
        FCount: Cardinal;
        procedure Grow;
    protected
        procedure SetTableLength(TableLen: Cardinal); virtual;
        procedure ReHash(TableLen: Cardinal);
        function Hash(const Str: WideString): Cardinal; virtual;
        function Find(const Name: WideString): PIHashItem;
        property Table: TArray<IHashItem> read FTable;
    public
        constructor Create;
        function Add(const Name: WideString; const Data: T): Boolean;
        function Get(const Name: WideString; out Data: T): Boolean;
        function Remove(const Name: WideString): Boolean;
        function Contains(const Name: WideString): Boolean;
        function GetEnumerator: THashEnumerator;
        procedure Clear;
    public
        property Count: Cardinal read FCount;
    end;


    ///
    /// Nem kis-nagy betu erzekeny szotar
    ///
    TNameValueCollection<T> = class sealed(TCustomNameValueCollection<T>)
    protected
        function Hash(const Str: WideString): Cardinal; override;
    end;


    TAppendable<T> = record
    private
        FResult: TArray<T>;
        FCount:  Integer;
        function GetResult: TArray<T>;
        function GetItem(Index: Integer): T;
        procedure SetItem(Index: Integer; Val: T);
    public
        class function Create: TAppendable<T>; static;
        procedure Append(const Val: T);
        procedure Clean;
        property Result: TArray<T> read GetResult;
        property Count: Integer read FCount;
        property Items[Index: Integer]: T read GetItem write SetItem; default;
    end;


    // TLinkedList<T> = class;


    TLinkedListNode<T> = class sealed(TInterfacedObject)
    strict private
        FNext, FPrev: IUnknown;
        FValue: T;
        FOwner: {TLinkedList<T>} TObject; // FPC BUG =(
        function GetNext: TLinkedListNode<T>;
        function GetPrev: TLinkedListNode<T>;
    private // Olvashato ebben a unit-ban
        procedure Remove;
        procedure InsertBefore(ANode: TLinkedListNode<T>);
        procedure InsertAfter(ANode: TLinkedListNode<T>);
        procedure InitializeHead;
    public
        constructor Create(const AValue: T);
        property Next: TLinkedListNode<T> read GetNext;
        property Prev: TLinkedListNode<T> read GetPrev;
        property Value: T read FValue;
        property Owner: {TLinkedList<T>} TObject read FOwner;
    end;


    TLinkedList<T> = class sealed
    private
        FHead: IUnknown;
        FCount: Integer;
        function GetHead: TLinkedListNode<T>;
        function GetTail: TLinkedListNode<T>;
    public
        function AddLast(const AValue: T): TLinkedListNode<T>;
        procedure RemoveFirst;
        procedure Remove(ANode: TLinkedListNode<T>);
        property Head: TLinkedListNode<T> read GetHead;
        property Tail: TLinkedListNode<T> read GetTail;
        property Count: Integer read FCount;
    end;


implementation


uses
    system.strings;


{$REGION THashItem}
constructor TCustomNameValueCollection<T>.THashItem.Create;
begin
    FName := AName;
    FData := AData;
end;


function TCustomNameValueCollection<T>.THashItem.Name;
begin
    Result := FName;
end;


function TCustomNameValueCollection<T>.THashItem.Data;
begin
    Result := FData;
end;


function TCustomNameValueCollection<T>.THashItem.Next;
begin
    Result := @FNext;
end;
{$ENDREGION}


{$REGION TCustomNameValueCollection}
constructor TCustomNameValueCollection<T>.Create;
begin
    inherited;
    SetTableLength(INITIAL_TABLE_SIZE);
end;


procedure TCustomNameValueCollection<T>.ReHash;
var
    Tmp: TCustomNameValueCollection<T>;
    I: TPair<T>;
begin
    //
    // Ahelyett h in place szamolgatnank ujra a hash-eket,
    // egyszerubb ha letrehozunk egy uj hash tablat adott
    // tablamerettel, majd abba masoljuk az eddig felvett
    // elemeket.
    //

    Tmp := ClassType.Create as TCustomNameValueCollection<T>; // Az aktualis tipust peldanyositjuk
    try
        Tmp.SetTableLength(TableLen);
        for I in Self do Tmp.Add(I.Name, I.Data);

        //
        // A regi tablat az ujra csereljuk.
        //

        FTable := Tmp.Table;
    finally
        Tmp.Free;
    end;
end;


procedure TCustomNameValueCollection<T>.Grow;
var
    NewCap: Cardinal;
begin
    if Length(FTable) = 0 then NewCap := 4
    else NewCap := Length(FTable) * 2;

    ReHash(NewCap);
end;


function TCustomNameValueCollection<T>.Hash;
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

    Result := Result mod Cardinal( Length(FTable) );
end;


function TCustomNameValueCollection<T>.Find;
begin
    //
    // Ugras a nevhez tartozo hash oszlopanak elso elemere.
    //

    Result := @FTable[ Hash(Name) ];

    //
    // Linearisan keressuk meg a nevhez tartozo elemet, v
    // az utolso elem Next mezojet.
    //

    while Assigned(Result^) do
    begin
        if Result^.Name.Equals(Name) then Exit;
        Result := Result.Next;
    end;
end;


function TCustomNameValueCollection<T>.Contains;
begin
    Result := Assigned( Find(Name)^ );
end;


function TCustomNameValueCollection<T>.Add;
var
    P: PIHashItem;
begin
    //
    // Ha az elemek szama a tablanak maximum 75%-a legyen.
    //

    if FCount >= Cardinal(Length(FTable) shr 1) + Cardinal(Length(FTable) shr 2) {75%} then
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
        P^ := THashItem.Create(Name, Data); // Torli a regi elemet (ha volt)
        Inc(FCount);
    end;
end;


function TCustomNameValueCollection<T>.Get;
var
    Hi: IHashItem;
begin
    Hi := Find(Name)^;
    Result := Assigned(Hi);
    if Result then Data := Hi.Data;
end;


function TCustomNameValueCollection<T>.Remove;
var
    Prev: PIHashItem;
    Hi: IHashItem;  // Kell az automatikus felszabaditashoz
begin
    Prev := Find(Name);
    Hi := Prev^;
    Result := Assigned(Hi);
    if Result then
    begin
        //
        // Ha letezik elem adott nevvel akkor kivesszuk a lancolt
        // listabol (felulirjuk a kovetkezo elemmel).
        //

        Prev^ := Hi.Next^;
        Dec(FCount);
    end;
end;


procedure TCustomNameValueCollection<T>.Clear;
begin
    SetTableLength(0); // Torli a korabbi elemeket
    SetTableLength(INITIAL_TABLE_SIZE);
    FCount := 0;
end;


procedure TCustomNameValueCollection<T>.SetTableLength;
begin
    SetLength(FTable, TableLen);
end;


function TCustomNameValueCollection<T>.GetEnumerator;
begin
    Result := THashEnumerator.Create(FTable);
end;
{$ENDREGION}


{$REGION THashEnumerator}
constructor TCustomNameValueCollection<T>.THashEnumerator.Create;
begin
    FTable := ATable;
end;


function TCustomNameValueCollection<T>.THashEnumerator.MoveNext;
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
            if FIndex = Length(FTable) then Exit(False);
            FCurrent := FTable[FIndex];
            Inc(FIndex);
        end;

        //
        // A kovetkezo meg bejaratlan elemen vagyunk.
        //

        if Assigned(FCurrent) then Exit(True);
    until False;
end;


function TCustomNameValueCollection<T>.THashEnumerator.GetCurrent;
begin
    Assert( Assigned(FCurrent) );

    //
    // Adat kiolvasasa.
    //

    Result.Name := FCurrent.Name;
    Result.Data := FCurrent.Data;
end;
{$ENDREGION}


{$REGION TNameValueCollection}
function TNameValueCollection<T>.Hash;
begin
    Result := inherited Hash(Str.LowerCase);
end;
{$ENDREGION}


{$REGION TAppendable}
class function TAppendable<T>.Create;
begin
    Result.FCount := 0;
end;


procedure TAppendable<T>.Append;
var
    Delta: Integer;
begin
    if Length(FResult) = FCount then
    begin
        if FCount = 0 then Delta := 4 else Delta := Length(FResult) * 2;
        SetLength(FResult, Delta);
    end;
    FResult[FCount] := Val;
    Inc(FCount);
end;


function TAppendable<T>.GetResult;
begin
    SetLength(FResult, FCount);
    Result := FResult; // NEM masolat...
end;


function TAppendable<T>.GetItem;
begin
    Assert((Index >= 0) and (Index < FCount));
    Result := FResult[Index];
end;


procedure TAppendable<T>.SetItem;
begin
    Assert((Index >= 0) and (Index < FCount));
    FResult[Index] := Val;
end;


procedure TAppendable<T>.Clean;
begin
    SetLength(FResult, 0);
    FCount := 0;
end;
{$ENDREGION}


{$REGION TLinkedListNode}
constructor TLinkedListNode<T>.Create;
begin
    inherited Create;
    FValue := AValue;
end;


function TLinkedListNode<T>.GetNext;
begin
    if Assigned(FNext) then Result := FNext as TLinkedListNode<T>
    else Result := nil;
end;


function TLinkedListNode<T>.GetPrev;
begin
    if Assigned(FPrev) then Result := FPrev as TLinkedListNode<T>
    else Result := nil;
end;


procedure TLinkedListNode<T>.Remove;
var
    {$IFDEF FPC}{$PUSH}{$NOTES OFF}{$ENDIF}
    LifeTime: IUnknown;
    {$IFDEF FPC}{$POP}{$ENDIF}
begin
    LifeTime := Self; // A Node csak a metodus lefutasat kovetoen szabaduljon fel
    if Assigned(FNext) then Next.FPrev := FPrev;
    if Assigned(FPrev) then Prev.FNext := FNext;

    FOwner := nil;
end;


procedure TLinkedListNode<T>.InsertBefore;
begin
    if Assigned(FPrev) then Prev.FNext := ANode;
    ANode.FPrev := FPrev;

    ANode.FNext := Self;
    FPrev := ANode;

    FOwner := ANode.Owner;
end;


procedure TLinkedListNode<T>.InsertAfter;
begin
    if Assigned(FNext) then Next.FPrev := ANode;
    ANode.FNext := FNext;

    ANode.FPrev := Self;
    FNext := ANode;

    FOwner := ANode.Owner;
end;


procedure TLinkedListNode<T>.InitializeHead;
begin
    FNext := Self;
    FPrev := Self;
end;
{$ENDREGION}


{$REGION TLinkedList}
function TLinkedList<T>.GetHead;
begin
    if Assigned(FHead) then Result := FHead as TLinkedListNode<T>
    else Result := nil;
end;


function TLinkedList<T>.GetTail;
begin
    if Assigned(Head) then Result := Head.Prev
    else Result := nil;
end;


function TLinkedList<T>.AddLast;
begin
    Result := TLinkedListNode<T>.Create(AValue);

    if Assigned(Head) then Head.InsertBefore(Result)
    else begin
        Result.InitializeHead();
        FHead := Result
    end;

    Inc(FCount);
end;


procedure TLinkedList<T>.RemoveFirst;
begin
    if Assigned(Head) then Remove(Head);
end;


procedure TLinkedList<T>.Remove;
begin
    Assert(ANode.Owner = Self);
    ANode.Remove();
    if ANode = Head then
    begin
        if FCount > 1 then FHead := Head.Next else FHead := nil;
    end;
    Dec(FCount);
end;
{$ENDREGION}


end.

