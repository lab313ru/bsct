unit ucompressor;

{$mode objfpc}{$H+}

interface

const
  THRESHOLD = 2;

type
  TBytesArray = array [0 .. $3FFFFF] of byte;
  PBytesArray = ^TBytesArray;

  TCompressor = class
  private
    FSrc, FDst, FCmdData: PBytesArray;

    FLength, FReadPos, FWritePos: word;
    FCmd: byte;
    FCmdBits: Shortint;
    FCmdDataPos: word;

    FMatchLen, FMatchPos: word;

    function FFindMatches: Boolean;
    function FFindUrepeatableBytes: word;

    function FReadOffset: word;
    procedure FWriteOffset(value: word);

    function FReadSrcWord(offset: word): word;

    procedure FReadCmdDataToken;
    procedure FWriteCmdDataToken;

    function FReadCopyCount: word;
    procedure FWriteCopyCount(value: word);

    function FReadCmdDataBits(count: byte = 1): word;
    procedure FWriteCmdDataBits(value: word; count: byte = 1);

    procedure FCopySrcToDestByReadCount;
    procedure FCopySrcToDestByWriteCount(count: word);

    procedure FCopyDestToDestByReadCount(offset: word);
    procedure FCopyDestToDestByWriteCount(offset, count: word);

    function FGetBitsCountOfValue(value: word): byte;


    procedure FInitVars;
  public
    constructor Create;

    function Decompress(src, dst: PBytesArray): word;
    function DecompressedSize(src: PBytesArray): word;
    function Compress(src, dst: PBytesArray; SrcSize: word): word;
    function CompressedSize(src: PBytesArray): word;
  end;

implementation

uses
  SysUtils;

const
  counts: array [0 .. 255] of byte = ($00, $01, $02, $02, $03, $03, $03, $03,
    $04, $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05, $05,
    $05, $05, $05, $05, $05, $05, $05, $05, $05, $06, $06, $06, $06, $06, $06,
    $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06,
    $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $07, $07, $07, $07,
    $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07,
    $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07,
    $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07,
    $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08,
    $08, $08, $08, $08, $08, $08, $08, $08);

function GetBit(Value: Word; Index: Byte): Byte;
begin
  Result := (Value shr Index) and 1;
end;

{ TCompressor }

constructor TCompressor.Create;
begin
  inherited Create;

  FSrc := nil;
  FDst := nil;
  FCmdData := nil;
end;

procedure TCompressor.FInitVars;
begin
  FReadPos := 0;
  FWritePos := 0;

  FLength := 0;

  FCmd := 0;
  FCmdBits := 0;

  FCmdDataPos := 0;
end;

function TCompressor.Decompress(src, dst: PBytesArray): word;
var
  off: word;
begin
  FInitVars;

  FDst := dst;
  FSrc := src;

  FLength := FReadSrcWord(0);
  off := FReadSrcWord(2);
  FCmdData := @FSrc^[off + 2];

  FReadPos := 4;
  FCopySrcToDestByReadCount;
  while (FWritePos < FLength) do
  begin
    FCopyDestToDestByReadCount(FReadOffset);

    if (FWritePos < FLength) and (FReadCmdDataBits = 0) then
      FCopySrcToDestByReadCount;
  end;

  Result := FWritePos;
end;

function TCompressor.Compress(src, dst: PBytesArray; SrcSize: word): word;
var
  count: word;
begin
  FInitVars;

  FLength := SrcSize;

  FSrc := src;
  FDst := @dst^[4];
  dst^[0] := Hi(FLength);
  dst^[1] := Lo(FLength);

  FCmdData := GetMemory($10000);

  FCmdBits := 8;

  FCopySrcToDestByWriteCount(FFindUrepeatableBytes);

  while (FReadPos < FLength) do
  begin
    if FFindMatches then
      FCopyDestToDestByWriteCount(FMatchPos, FMatchLen);

    count := FFindUrepeatableBytes;

    if count > 0 then
      FWriteCmdDataBits(0);

    FCopySrcToDestByWriteCount(count);
  end;
  FWriteCmdDataToken;

  dst^[2] := Hi(Word(FWritePos + 2));
  dst^[3] := Lo(Word(FWritePos + 2));

  Result := FWritePos + 4 + FCmdDataPos;
  Move(FCmdData^[0], FDst^[FWritePos], FCmdDataPos);

  FreeMemory(FCmdData);
end;

function TCompressor.DecompressedSize(src: PBytesArray): word;
begin
  Result := (src^[0] shl 8) or src^[1];
end;

function TCompressor.CompressedSize(src: PBytesArray): word;
begin
  FInitVars;

  FSrc := src;
  FDst := GetMemory($10000);

  FLength := FReadSrcWord(0);
  FCmdData := @FSrc^[FReadSrcWord(2) + 2];

  FReadPos := 4;
  FCopySrcToDestByReadCount;
  while (FWritePos < FLength) do
  begin
    FCopyDestToDestByReadCount(FReadOffset);

    if (FWritePos < FLength) and (FReadCmdDataBits = 0) then
      FCopySrcToDestByReadCount;
  end;

  Result := FReadPos + FCmdDataPos;

  FreeMemory(FDst);
end;

procedure TCompressor.FCopySrcToDestByReadCount;
var
  count: word;
begin
  count := FReadCopyCount;
  while (count > 0) do
  begin
    FDst^[FWritePos] := FSrc^[FReadPos];
    INC(FWritePos);
    INC(FReadPos);
    Dec(count);
  end;
end;

procedure TCompressor.FCopySrcToDestByWriteCount(count: word);
begin
  FWriteCopyCount(count);
  while (count > 0) do
  begin
    FDst^[FWritePos] := FSrc^[FReadPos];
    INC(FWritePos);
    INC(FReadPos);
    Dec(count);
  end;
end;

procedure TCompressor.FCopyDestToDestByReadCount(offset: word);
var
  I, count: word;
begin
  count := FReadCopyCount + 2;
  for I := 1 to count do
  begin
    FDst^[FWritePos] := FDst^[offset + I - 1];
    INC(FWritePos);
  end;
end;

procedure TCompressor.FCopyDestToDestByWriteCount(offset, count: word);
begin
  FWriteOffset(offset);
  FWriteCopyCount(count - 2);
  Inc(FReadPos, count);
end;

function TCompressor.FFindMatches: Boolean;
var
  MinPos: Integer;
  BufPos: Integer;
  TempLen: Integer;
  bits: byte;
begin
  FMatchLen := THRESHOLD;
  BufPos := FReadPos - 1;
  MinPos := 0;

  TempLen := THRESHOLD;
  while BufPos >= MinPos do
  begin
    while CompareMem(@FSrc^[BufPos], @FSrc^[FReadPos], TempLen) and
      ((FReadPos + TempLen) <= FLength)
    do
    begin
      FMatchLen := TempLen;
      FMatchPos := Word(BufPos);
      INC(TempLen);
    end;
    Dec(BufPos);

    if (Hi(FReadPos) = 0) then
      bits := 0 + counts[Lo(FReadPos)]
    else
      bits := 8 + counts[Hi(FReadPos)];

    if FGetBitsCountOfValue(FMatchPos) > bits then
      Dec(TempLen);
  end;

  Result := (FMatchLen > THRESHOLD);
end;

function TCompressor.FFindUrepeatableBytes: word;
begin
  Result := 0;
  while (FReadPos < FLength) and (not FFindMatches) do
  begin
    INC(Result);
    INC(FReadPos);
  end;
  Dec(FReadPos, Result);
end;

function TCompressor.FGetBitsCountOfValue(value: word): byte;
begin
  if value = 0 then
  begin
    Result := 1;
    Exit;
  end;

  Result := 0;

  while value <> 1 do
  begin
    Inc(Result);
    value := value shr 1;
  end;
  Inc(Result);
end;

function TCompressor.FReadOffset: word;
begin
  if (Hi(FWritePos) = 0) then
    Result := FReadCmdDataBits(0 + counts[Lo(FWritePos)])
  else
    Result := FReadCmdDataBits(8 + counts[Hi(FWritePos)]);
end;

procedure TCompressor.FWriteOffset(value: word);
begin
  if (Hi(FReadPos) = 0) then
    FWriteCmdDataBits(value, 0 + counts[Lo(FReadPos)])
  else
    FWriteCmdDataBits(value, 8 + counts[Hi(FReadPos)]);
end;

function TCompressor.FReadCmdDataBits(count: byte): word;
begin
  Result := 0;

  while (count > 0) do
  begin
    Dec(FCmdBits);

    if (FCmdBits < 0) then
    begin
      FCmdBits := 7;
      FReadCmdDataToken;
    end;

    Result := (Result shl 1) or GetBit(FCmd, 7);
    FCmd := (FCmd and $7F) shl 1;

    Dec(count);
  end;
end;

procedure TCompressor.FWriteCmdDataBits(value: word; count: byte);
begin
  while (count > 0) do
  begin
    Dec(FCmdBits);

    if (FCmdBits < 0) then
    begin
      FCmdBits := 7;
      FWriteCmdDataToken;
      FCmd := 0;
    end;

    FCmd := (GetBit(value, count - 1) shl FCmdBits) or FCmd;

    Dec(count);
  end;
end;

function TCompressor.FReadCopyCount: word;
begin
  Result := 1;

  while (FReadCmdDataBits = 0) and (FWritePos + Result < FLength) do
  begin
    Result := (Result shl 1) or FReadCmdDataBits;
  end;
end;

procedure TCompressor.FWriteCopyCount(value: word);
var
  bits: byte;
begin
  if value <= 1 then
    FWriteCmdDataBits(1)
  else
  begin
    bits := FGetBitsCountOfValue(value) - 1;

    while bits > 0 do
    begin
      FWriteCmdDataBits(0);
      FWriteCmdDataBits(GetBit(value, bits - 1));
      Dec(bits);
    end;
    FWriteCmdDataBits(1);
  end;
end;

procedure TCompressor.FReadCmdDataToken;
begin
  FCmd := FCmdData^[FCmdDataPos + 0];
  INC(FCmdDataPos);
end;

procedure TCompressor.FWriteCmdDataToken;
begin
  FCmdData^[FCmdDataPos + 0] := FCmd;
  INC(FCmdDataPos);
end;

function TCompressor.FReadSrcWord(offset: word): word;
begin
  Result := (FSrc^[offset + 0] shl 8) or FSrc^[offset + 1];
end;

end.
