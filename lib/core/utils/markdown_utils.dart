String markdownToPlainText(String source) {
  String text = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  text = text.replaceAllMapped(
    RegExp(r'```([\s\S]*?)```'),
    (Match match) => '\n${(match.group(1) ?? '').trim()}\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'`([^`]*)`'),
    (Match match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (Match match) {
      final String alt = (match.group(1) ?? '').trim();
      return alt.isEmpty ? '图片' : alt;
    },
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (Match match) => match.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*([-*_]\s*){3,}$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'[*_~]'), '');
  text = text.replaceAll('|', ' ');
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n[ \t]+'), '\n');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}
