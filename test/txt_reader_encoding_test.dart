/// Tests for TXT encoding sniffing (analysis item #2, §3.5 protected
/// surface): BOM handling, UTF-16 support, and — critically — that valid
/// UTF-8/GBK books decode byte-for-byte identically to the legacy chain so
/// existing line-index anchors do not move.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

const _cjkSample = '第一章 起点\n她说：“你好，世界。”\n第二章 终点\n完。\n';
const _latinSample = 'Chapter One\nHello, world.\nThe End.\n';

Uint8List _utf16Bytes(String text, {required Endian endian, bool bom = true}) {
  final units = text.codeUnits;
  final out = BytesBuilder();
  void writeUnit(int u) {
    if (endian == Endian.little) {
      out.add([u & 0xFF, (u >> 8) & 0xFF]);
    } else {
      out.add([(u >> 8) & 0xFF, u & 0xFF]);
    }
  }

  if (bom) writeUnit(0xFEFF);
  units.forEach(writeUnit);
  return out.toBytes();
}

void main() {
  group('anchor stability — legacy paths must not change', () {
    test('plain UTF-8 (no BOM) decodes identically to utf8.decode', () {
      final bytes = Uint8List.fromList(utf8.encode(_cjkSample));
      expect(decodeTxtBytesForParse(bytes), utf8.decode(bytes));
    });

    test('GBK decodes identically to gbk.decode', () {
      final bytes = Uint8List.fromList(gbk.encode(_cjkSample));
      expect(decodeTxtBytesForParse(bytes), gbk.decode(bytes));
    });

    test('pure ASCII decodes unchanged', () {
      final bytes = Uint8List.fromList(ascii.encode(_latinSample));
      expect(decodeTxtBytesForParse(bytes), _latinSample);
    });
  });

  group('BOM detection', () {
    test('UTF-8 BOM is stripped', () {
      final bytes =
          Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(_cjkSample)]);
      expect(decodeTxtBytesForParse(bytes), _cjkSample);
    });

    test('UTF-16 LE with BOM (Windows Notepad "Unicode") decodes correctly',
        () {
      final bytes = _utf16Bytes(_cjkSample, endian: Endian.little);
      expect(decodeTxtBytesForParse(bytes), _cjkSample);
    });

    test('UTF-16 BE with BOM decodes correctly', () {
      final bytes = _utf16Bytes(_cjkSample, endian: Endian.big);
      expect(decodeTxtBytesForParse(bytes), _cjkSample);
    });

    test('UTF-16 LE handles surrogate pairs (non-BMP chars)', () {
      const text = 'emoji: \u{1F431} cat\n';
      final bytes = _utf16Bytes(text, endian: Endian.little);
      expect(decodeTxtBytesForParse(bytes), text);
    });
  });

  group('BOM-less UTF-16 heuristic', () {
    test('detects ASCII-heavy UTF-16 LE without BOM', () {
      final bytes = _utf16Bytes(_latinSample, endian: Endian.little, bom: false);
      expect(decodeTxtBytesForParse(bytes), _latinSample);
    });

    test('detects ASCII-heavy UTF-16 BE without BOM', () {
      final bytes = _utf16Bytes(_latinSample, endian: Endian.big, bom: false);
      expect(decodeTxtBytesForParse(bytes), _latinSample);
    });

    test('does not misfire on CJK UTF-8 (no NUL bytes)', () {
      // Long sample so the ratio window is well populated.
      final text = _cjkSample * 100;
      final bytes = Uint8List.fromList(utf8.encode(text));
      expect(decodeTxtBytesForParse(bytes), text);
    });
  });

  group('last-resort guard', () {
    test('latin1 still serves plausible Latin text with accents', () {
      // ISO-8859-1 bytes: invalid as UTF-8, mostly ASCII with a few accents.
      final text = 'Café au lait, s’il te plaît?\n'
          .replaceAll('’', "'");
      final bytes = latin1.encode('$text${_latinSample * 4}');
      expect(decodeTxtBytesForParse(Uint8List.fromList(bytes)),
          latin1.decode(bytes));
    });

    test('truncated UTF-16 file drops the odd trailing byte', () {
      final whole = _utf16Bytes(_cjkSample, endian: Endian.little);
      final truncated = Uint8List.fromList([...whole, 0x4E]);
      expect(decodeTxtBytesForParse(truncated), _cjkSample);
    });
  });
}
