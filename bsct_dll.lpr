library bsct_dll;

{$mode objfpc}{$H+}

uses
  uCompressor;

function Decompress(src, dst: Pointer): word; export; cdecl;
var
  actCmp: TCompressor;
begin
  actCmp := TCompressor.Create;
  Result := actCmp.Decompress(src, dst);
  actCmp.Free;
end;

function DecompressedSize(src: Pointer): word; export; cdecl;
var
  actCmp: TCompressor;
begin
  actCmp := TCompressor.Create;
  Result := actCmp.DecompressedSize(src);
  actCmp.Free;
end;

function Compress(src, dst: Pointer; Length: word): word; export; cdecl;
var
  actCmp: TCompressor;
begin
  actCmp := TCompressor.Create;
  Result := actCmp.Compress(src, dst, Length);
  actCmp.Free;
end;

function CompressedSize(src: Pointer): word; export; cdecl;
var
  actCmp: TCompressor;
begin
  actCmp := TCompressor.Create;
  Result := actCmp.CompressedSize(src);
  actCmp.Free;
end;

exports
  Decompress, DecompressedSize, Compress, CompressedSize;

begin

end.


