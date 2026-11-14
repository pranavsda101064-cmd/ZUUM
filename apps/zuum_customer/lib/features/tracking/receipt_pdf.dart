import 'dart:convert';
import 'dart:typed_data';

/// Minimal single-page PDF writer for trip receipts (no external deps).
/// Produces a valid PDF 1.4 file with Helvetica text lines.
abstract final class ReceiptPdf {
  static Uint8List build({
    required String title,
    required List<String> lines,
  }) {
    final content = StringBuffer();
    content.writeln('BT');
    content.writeln('/F1 11 Tf');
    content.writeln('48 792 Td');
    var first = true;
    for (final raw in lines) {
      final line = _truncate(_escape(raw), 90);
      if (first) {
        content.writeln('($line) Tj');
        first = false;
      } else {
        content.writeln('0 -16 Td');
        content.writeln('($line) Tj');
      }
    }
    content.writeln('ET');
    // Title bar emphasis.
    final header = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 14 Tf')
      ..writeln('48 812 Td')
      ..writeln('(${_escape(_truncate(title, 70))}) Tj')
      ..writeln('ET');

    final stream = utf8.encode('$header$content');
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Length ${stream.length} >>\nstream\n'
          '${utf8.decode(stream)}\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];

    final buffer = BytesBuilder();
    buffer.add(utf8.encode('%PDF-1.4\n'));
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.add(utf8.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
    }
    final xrefStart = buffer.length;
    final xref = StringBuffer('xref\n0 ${objects.length + 1}\n')
      ..writeln('0000000000 65535 f ');
    for (final off in offsets) {
      xref.writeln('${off.toString().padLeft(10, '0')} 00000 n ');
    }
    buffer.add(utf8.encode(xref.toString()));
    buffer.add(utf8.encode(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefStart\n%%EOF\n',
    ));
    return buffer.toBytes();
  }

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';
}
