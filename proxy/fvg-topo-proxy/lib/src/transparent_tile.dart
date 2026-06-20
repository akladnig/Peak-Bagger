import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final transparentTilePngBytes = List<int>.unmodifiable(
  buildTransparentPng(size: 256),
);

List<int> buildTransparentPng({required int size}) {
  final raw = BytesBuilder(copy: false);
  for (var row = 0; row < size; row++) {
    raw.addByte(0);
    raw.add(List<int>.filled(size * 4, 0));
  }

  final compressed = ZLibEncoder().convert(raw.takeBytes());
  return [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ..._pngChunk('IHDR', _ihdrData(size)),
    ..._pngChunk('IDAT', compressed),
    ..._pngChunk('IEND', const []),
  ];
}

List<int> _ihdrData(int size) {
  final data = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  return data.buffer.asUint8List();
}

List<int> _pngChunk(String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final length = ByteData(4)..setUint32(0, data.length);
  final crcSource = <int>[...typeBytes, ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(crcSource));
  return [
    ...length.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = 0xedb88320 ^ (crc >> 1);
      } else {
        crc >>= 1;
      }
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
