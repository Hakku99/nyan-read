import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const pdfWidth = 256;
const pdfHeight = 384;
const _white = 0xFFFFFF;

enum PdfFixture {
  scan([
    (left: 0xB92F3C, right: 0xE78827, marker: 0xFCDF65, center: 0xE78827),
    (left: 0x236BB9, right: 0x267D55, marker: 0xCDEDA2, center: 0x267D55),
  ]),
  multipleImages([
    (left: 0x722AB2, right: 0x16868D, marker: 0x303030, center: _white),
    (left: 0xC94328, right: 0x4E742F, marker: 0x28458F, center: _white),
  ]);

  const PdfFixture(this.pages);

  final List<PdfPageColors> pages;
}

typedef PdfPageColors = ({int left, int right, int marker, int center});

Future<void> writePdfFixtures(String directory) async {
  for (final fixture in PdfFixture.values) {
    final pdf = _Pdf();
    for (final colors in fixture.pages) {
      if (fixture == PdfFixture.scan) {
        // A single full-bleed JPEG with a marker baked into its top half.
        final scan = _solidImage(pdfWidth * 2, pdfHeight * 2, colors.left);
        img.fillRect(scan,
            x1: pdfWidth,
            y1: 0,
            x2: scan.width - 1,
            y2: scan.height - 1,
            color: _rgb(colors.right));
        img.fillRect(scan,
            x1: 224, y1: 128, x2: 287, y2: 191, color: _rgb(colors.marker));
        pdf.addPage(
          'q $pdfWidth 0 0 $pdfHeight 0 0 cm /Scan Do Q',
          {'Scan': pdf.addJpeg(scan)},
        );
      } else {
        // Two independent images, a white gutter and a PDF vector marker.
        final left = pdf.addJpeg(_solidImage(192, 384, colors.left));
        final right = pdf.addJpeg(_solidImage(192, 384, colors.right));
        final fill = [
          colors.marker >> 16,
          (colors.marker >> 8) & 255,
          colors.marker & 255,
        ].map((channel) => (channel / 255).toStringAsFixed(5)).join(' ');
        pdf.addPage(
          'q 96 0 0 192 0 96 cm /Left Do Q\n'
          'q 96 0 0 192 160 96 cm /Right Do Q\n'
          '$fill rg 112 288 32 32 re f',
          {'Left': left, 'Right': right},
        );
      }
    }
    await File('$directory/${fixture.name}.pdf').writeAsBytes(pdf.encode());
  }
}

img.ColorRgb8 _rgb(int rgb) =>
    img.ColorRgb8(rgb >> 16, (rgb >> 8) & 255, rgb & 255);

img.Image _solidImage(int width, int height, int color) =>
    img.fill(img.Image(width: width, height: height), color: _rgb(color));

// Store byte offsets and stream lengths, since JPEG streams are binary.
final class _Pdf {
  final _objects = <List<int>>[[], []];
  final _pages = <int>[];

  int _add(List<int> object) {
    _objects.add(object);
    return _objects.length;
  }

  int _stream(String dictionary, List<int> data) => _add([
        ...ascii.encode('<< $dictionary /Length ${data.length} >>\nstream\n'),
        ...data,
        ...ascii.encode('\nendstream'),
      ]);

  int addJpeg(img.Image image) => _stream(
        '/Type /XObject /Subtype /Image /Width ${image.width} '
        '/Height ${image.height} /ColorSpace /DeviceRGB '
        '/BitsPerComponent 8 /Filter /DCTDecode',
        img.encodeJpg(image, quality: 90),
      );

  void addPage(String commands, Map<String, int> images) {
    final contents = _stream('', ascii.encode(commands));
    final resources = images.entries
        .map((entry) => '/${entry.key} ${entry.value} 0 R')
        .join(' ');
    _pages.add(_add(ascii.encode(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pdfWidth $pdfHeight] '
        '/Resources << /XObject << $resources >> >> /Contents $contents 0 R >>')));
  }

  Uint8List encode() {
    _objects[0] = ascii.encode('<< /Type /Catalog /Pages 2 0 R >>');
    final kids = _pages.map((page) => '$page 0 R').join(' ');
    _objects[1] = ascii
        .encode('<< /Type /Pages /Count ${_pages.length} /Kids [$kids] >>');
    final bytes = BytesBuilder()..add(latin1.encode('%PDF-1.4\n%âãÏÓ\n'));
    final offsets = <int>[];
    for (var i = 0; i < _objects.length; i++) {
      offsets.add(bytes.length);
      bytes.add(ascii.encode('${i + 1} 0 obj\n'));
      bytes.add(_objects[i]);
      bytes.add(ascii.encode('\nendobj\n'));
    }
    final xref = bytes.length;
    bytes.add(
        ascii.encode('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n'));
    for (final offset in offsets) {
      bytes.add(
          ascii.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
    }
    bytes.add(
        ascii.encode('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n'
            'startxref\n$xref\n%%EOF\n'));
    return bytes.takeBytes();
  }
}
