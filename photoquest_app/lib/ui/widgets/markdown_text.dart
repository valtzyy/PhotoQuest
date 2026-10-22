import 'package:flutter/material.dart';

import '../../core/pq_colors.dart';

/// Render markdown sederhana dari jawaban LLM: judul `#`, bullet `-`/`*`/`•`,
/// daftar bernomor `1.`, serta inline `**tebal**`, `*miring*`, dan `` `kode` ``.
/// Sintaks lain ditampilkan apa adanya. Teks bisa diseleksi untuk disalin.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key});

  final String data;

  static final _bullet = RegExp(r'^(\s*)[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^(\s*)(\d+[.)])\s+(.*)$');
  static final _heading = RegExp(r'^#{1,6}\s+(.*)$');
  static final _inline = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|\*(?=\S)(.+?)(?<=\S)\*|`([^`]+)`',
  );

  /// Pecah teks menjadi span: bagian bertanda markdown diberi gaya, tandanya dibuang.
  static List<TextSpan> inlineSpans(String text, Color strong) {
    final spans = <TextSpan>[];
    var start = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      final bold = m.group(1) ?? m.group(2);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: TextStyle(fontWeight: FontWeight.w700, color: strong),
          ),
        );
      } else if (m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(3),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = PqColors.of(context);
    final blocks = <Widget>[];
    final paragraph = <String>[];

    Widget rich(String text, {TextStyle? style}) => Text.rich(
      TextSpan(style: style, children: inlineSpans(text, colors.heading)),
    );

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(rich(paragraph.join('\n')));
      paragraph.clear();
    }

    Widget listItem(String indent, String marker, String text) => Padding(
      padding: EdgeInsets.only(left: indent.length * 6.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: const TextStyle(
                color: PqPalette.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: rich(text)),
        ],
      ),
    );

    for (final line in data.trim().split('\n')) {
      final heading = _heading.firstMatch(line);
      final bullet = _bullet.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      if (line.trim().isEmpty) {
        flushParagraph();
        if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 8));
      } else if (heading != null) {
        flushParagraph();
        blocks.add(
          rich(
            heading.group(1)!,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.heading,
            ),
          ),
        );
      } else if (bullet != null) {
        flushParagraph();
        blocks.add(listItem(bullet.group(1)!, '•', bullet.group(2)!));
      } else if (numbered != null) {
        flushParagraph();
        blocks.add(
          listItem(numbered.group(1)!, numbered.group(2)!, numbered.group(3)!),
        );
      } else {
        paragraph.add(line);
      }
    }
    flushParagraph();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: blocks,
      ),
    );
  }
}
