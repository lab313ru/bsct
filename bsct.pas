program bsct;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, strutils, FileUtil, ucompressor
  { you can add units after this };

type

  { TBsctCmp }

  TBsctCmp = class(TCustomApplication)
  protected
    procedure DoRun; override;
  private
    procedure actDecompress(const inStr: string; OFFSET: Integer);
    procedure actCompress(const inStr: string);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TBsctCmp }

procedure TBsctCmp.actDecompress(const inStr: string; OFFSET: Integer);
var
  C_STREAM, D_STREAM: TFileStream;
  C_BUF, D_BUF: PBytesArray;
  TCP: TCompressor;
  D_SIZE, C_SIZE: Integer;
  outStr: string;
begin
  TCP := TCompressor.Create;

  C_STREAM := TFileStream.Create(inStr, fmOpenRead or fmShareExclusive);
  C_STREAM.Seek(OFFSET, soBeginning);
  outStr := ChangeFileExt(inStr,
                          Format('.%.4X%s', [OFFSET, ExtractFileExt(inStr)]));
  D_STREAM := TFileStream.Create(outStr, fmOpenWrite or fmCreate or fmShareExclusive);

  New(C_BUF);
  New(D_BUF);
  C_SIZE := C_STREAM.Size;
  C_STREAM.Read(C_BUF^[0], C_SIZE);
  C_SIZE := TCP.CompressedSize(C_BUF);


  D_SIZE := TCP.Decompress(C_BUF, D_BUF);
  TCP.Free;

  D_STREAM.Write(D_BUF^[0], D_SIZE);
  C_STREAM.Destroy;
  D_STREAM.Destroy;
  Dispose(C_BUF);
  Dispose(D_BUF);

  Writeln('Decompressed file was save as: "' + ExtractFileName(outStr) + '";');
  Writeln('Compressed size: ' + IntToStr(C_SIZE) + ' bytes;');
  Writeln('Decompressed size: ' + IntToStr(D_SIZE) + ' bytes.');
end;

procedure TBsctCmp.actCompress(const inStr: string);
var
  C_STREAM, D_STREAM: TFileStream;
  C_BUF, D_BUF: PBytesArray;
  TCP: TCompressor;
  D_SIZE, C_SIZE: Integer;
  outStr: string;
begin
  TCP := TCompressor.Create;

  D_STREAM := TFileStream.Create(inStr, fmOpenRead or fmShareExclusive);
  outStr := ChangeFileExt(inStr,
                          Format('.cmp%s', [ExtractFileExt(inStr)]));
  C_STREAM := TFileStream.Create(outStr, fmOpenWrite or fmCreate or fmShareExclusive);

  New(C_BUF);
  New(D_BUF);
  D_SIZE := D_STREAM.Size;
  D_STREAM.Read(D_BUF^[0], D_SIZE);


  C_SIZE := TCP.Compress(D_BUF, C_BUF, D_SIZE);
  TCP.Free;

  C_STREAM.Write(C_BUF^[0], C_SIZE);
  D_STREAM.Destroy;
  C_STREAM.Destroy;
  Dispose(C_BUF);
  Dispose(D_BUF);

  Writeln('Compressed file was save as: "' + ExtractFileName(outStr) + '";');
  Writeln('Decompressed size: ' + IntToStr(D_SIZE) + ' bytes;');
  Writeln('Compressed size: ' + IntToStr(C_SIZE) + ' bytes.');
end;

procedure TBsctCmp.DoRun;
var
  OFFSET: Integer;

begin
  // quick check parameters
  if not FileExists(ParamStr(1)) then
  begin
    Writeln('File not found: "' + ExtractFileName(ParamStr(1)) + '"' + #13#10);
    Terminate;
  end;

  if ParamCount = 2 then
  begin
    OFFSET := Hex2Dec(ParamStr(2));
    if FileSize(ParamStr(1)) <= OFFSET then
    begin
      Writeln('Specified offset is greater than size of packed data!' + #13#10);
      Terminate;
      Exit;
    end;

    Writeln('Decompressing "' + ExtractFileName(ParamStr(1)) + '" from 0x' +
      IntToHex(OFFSET, 4) + '...');

    actDecompress(ParamStr(1), OFFSET);
  end
  else if ParamCount = 1 then
  begin
    Writeln('Compressing "' + ExtractFileName(ParamStr(1)) + '"...');
    actCompress(ParamStr(1));
  end
  else
    WriteHelp;

  // stop program loop
  Terminate;
end;

constructor TBsctCmp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TBsctCmp.Destroy;
begin
  inherited Destroy;
end;

procedure TBsctCmp.WriteHelp;
begin
  Writeln('-= Beam Software Compression Tool (BSCT) v1.0 [by Lab 313] (21.10.2014) =-');
  Writeln('-----------------------------');
  Writeln('Compression type: LZ77-Like');
  Writeln('Decompressor | Compressor: Dr. MefistO');
  Writeln('Coding: Dr. MefistO');
  Writeln('FindMatches help: Marat [Chief-Net]');
  Writeln('Our site: http://lab313.ru');
  Writeln('Info: This console tool allows you to compress and decompress' +
    #13#10 + '      data, compressed by the Beam Software compression algo.' + #13#10);
  Writeln('USAGE FOR DECOMPRESSION:' + #13#10 +
    'bsct.exe [Filename] [HexOffset]' + #13#10 +
    'EXAMPLE:' + #13#10 +
    'bsct.exe "Radical Rex (U) [!].bin" DFC4' + #13#10);
  Writeln('USAGE FOR COMPRESSION:' + #13#10 +
    'bsct.exe [InFilename]' + #13#10 +
    'EXAMPLE:' + #13#10 +
    'bsct.exe DFC4.bin' + #13#10 +
    '-----------------------------' + #13#10);
end;

var
  Application: TBsctCmp;
begin
  Application:=TBsctCmp.Create(nil);
  Application.Title:='Beam Software Compression Tool';
  Application.Run;
  Application.Free;
end.

