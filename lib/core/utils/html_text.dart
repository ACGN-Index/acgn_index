import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

final RegExp _htmlTagPattern = RegExp(r'</?[A-Za-z][^>]*>');

/// 把 HTML 片段按块级标签切成纯文本，段落之间用单个换行分隔。
String htmlToPlainText(String source) {
  final fragment = html_parser.parseFragment(source);
  final buffer = StringBuffer();

  void writeNode(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is dom.Element) {
      final isBlock = _blockTags.contains(node.localName);
      if (isBlock && buffer.isNotEmpty) {
        buffer.write('\n');
      }
      for (final child in node.nodes) {
        writeNode(child);
      }
      if (isBlock && buffer.isNotEmpty) {
        buffer.write('\n');
      }
    }
  }

  for (final node in fragment.nodes) {
    writeNode(node);
  }
  return _normalizeLines(buffer.toString()).join('\n');
}

/// 把正文拆成段落：HTML 走块级标签，纯文本按空行或换行拆分。
List<String> htmlToParagraphs(String source) {
  if (_htmlTagPattern.hasMatch(source)) {
    return _normalizeLines(htmlToPlainText(source));
  }
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  if (blocks.length > 1) {
    return blocks
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList(growable: false);
  }
  return _normalizeLines(normalized);
}

List<String> _normalizeLines(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

const Set<String> _blockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'br',
  'dd',
  'div',
  'dl',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'td',
  'th',
  'tr',
  'ul',
};
