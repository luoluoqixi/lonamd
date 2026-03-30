import 'package:lonamd/src/markdown/md_block_context.dart';
import 'package:lonamd/src/markdown/md_element.dart';
import 'package:lonamd/src/markdown/md_node_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to collect all elements of a specific type from the tree
List<MdElement> collect(MdElement root, MdNodeType type) {
  final result = <MdElement>[];
  void walk(MdElement e) {
    if (e.type == type) result.add(e);
    for (final c in e.children) {
      walk(c);
    }
  }

  walk(root);
  return result;
}

/// Helper to check that the tree contains a given type
bool hasType(MdElement root, MdNodeType type) => collect(root, type).isNotEmpty;

/// Debug print the tree
String dumpTree(MdElement e, [int indent = 0]) {
  final sb = StringBuffer();
  sb.writeln('${'  ' * indent}${e.type.name}(${e.from}, ${e.to})');
  for (final c in e.children) {
    sb.write(dumpTree(c, indent + 1));
  }
  return sb.toString();
}

void main() {
  late MdMarkdownParserImpl parser;

  setUp(() {
    parser = defaultMarkdownParser();
  });

  group('ATX Headings', () {
    test('# heading level 1', () {
      final doc = parser.parseDocument('# Hello');
      expect(hasType(doc, MdNodeType.atxHeading1), isTrue);
    });

    test('## heading level 2', () {
      final doc = parser.parseDocument('## World');
      expect(hasType(doc, MdNodeType.atxHeading2), isTrue);
    });

    test('###### heading level 6', () {
      final doc = parser.parseDocument('###### Deep');
      expect(hasType(doc, MdNodeType.atxHeading6), isTrue);
    });

    test('####### not a heading (7 hashes)', () {
      final doc = parser.parseDocument('####### TooDeep');
      expect(hasType(doc, MdNodeType.paragraph), isTrue);
    });
  });

  group('Paragraphs', () {
    test('simple paragraph', () {
      final doc = parser.parseDocument('Hello world');
      expect(doc.type, MdNodeType.document);
      expect(hasType(doc, MdNodeType.paragraph), isTrue);
    });

    test('multi-line paragraph', () {
      final doc = parser.parseDocument('Line one\nLine two');
      final paras = collect(doc, MdNodeType.paragraph);
      expect(paras.length, 1);
    });

    test('two paragraphs separated by blank line', () {
      final doc = parser.parseDocument('Para one\n\nPara two');
      final paras = collect(doc, MdNodeType.paragraph);
      expect(paras.length, 2);
    });
  });

  group('Horizontal Rule', () {
    test('--- is horizontal rule', () {
      final doc = parser.parseDocument('---');
      expect(hasType(doc, MdNodeType.horizontalRule), isTrue);
    });

    test('*** is horizontal rule', () {
      final doc = parser.parseDocument('***');
      expect(hasType(doc, MdNodeType.horizontalRule), isTrue);
    });

    test('___ is horizontal rule', () {
      final doc = parser.parseDocument('___');
      expect(hasType(doc, MdNodeType.horizontalRule), isTrue);
    });
  });

  group('Fenced Code', () {
    test('backtick fenced code', () {
      final doc = parser.parseDocument('```\ncode\n```');
      expect(hasType(doc, MdNodeType.fencedCode), isTrue);
      final marks = collect(doc, MdNodeType.codeMark);
      expect(marks.length, 2); // opening and closing
    });

    test('fenced code with info string', () {
      final doc = parser.parseDocument('```dart\nprint("hi");\n```');
      expect(hasType(doc, MdNodeType.fencedCode), isTrue);
      expect(hasType(doc, MdNodeType.codeInfo), isTrue);
    });

    test('tilde fenced code', () {
      final doc = parser.parseDocument('~~~\ncode\n~~~');
      expect(hasType(doc, MdNodeType.fencedCode), isTrue);
    });
  });

  group('Indented Code', () {
    test('4-space indented code', () {
      final doc = parser.parseDocument('    code line');
      expect(hasType(doc, MdNodeType.codeBlock), isTrue);
    });
  });

  group('Blockquote', () {
    test('simple blockquote', () {
      final doc = parser.parseDocument('> quoted text');
      expect(hasType(doc, MdNodeType.blockquote), isTrue);
      expect(hasType(doc, MdNodeType.quoteMark), isTrue);
    });

    test('multi-line blockquote', () {
      final doc = parser.parseDocument('> line 1\n> line 2');
      expect(hasType(doc, MdNodeType.blockquote), isTrue);
    });
  });

  group('Bullet List', () {
    test('simple bullet list', () {
      final doc = parser.parseDocument('- item 1\n- item 2');
      expect(hasType(doc, MdNodeType.bulletList), isTrue);
      final items = collect(doc, MdNodeType.listItem);
      expect(items.length, 2);
    });

    test('nested bullet list', () {
      final doc = parser.parseDocument('- outer\n  - inner');
      expect(hasType(doc, MdNodeType.bulletList), isTrue);
      final items = collect(doc, MdNodeType.listItem);
      expect(items.length, 2);
    });
  });

  group('Ordered List', () {
    test('simple ordered list', () {
      final doc = parser.parseDocument('1. first\n2. second');
      expect(hasType(doc, MdNodeType.orderedList), isTrue);
      final items = collect(doc, MdNodeType.listItem);
      expect(items.length, 2);
    });
  });

  group('Setext Headings', () {
    test('=== underline creates heading 1', () {
      final doc = parser.parseDocument('Heading\n=======');
      expect(hasType(doc, MdNodeType.setextHeading1), isTrue);
    });

    test('--- underline creates heading 2', () {
      final doc = parser.parseDocument('Heading\n-------');
      expect(hasType(doc, MdNodeType.setextHeading2), isTrue);
    });
  });

  group('Inline Parsing', () {
    test('emphasis', () {
      final doc = parser.parseDocument('*hello*');
      expect(hasType(doc, MdNodeType.emphasis), isTrue);
    });

    test('strong', () {
      final doc = parser.parseDocument('**bold**');
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
    });

    test('inline code', () {
      final doc = parser.parseDocument('`code`');
      expect(hasType(doc, MdNodeType.inlineCode), isTrue);
    });

    test('link', () {
      final doc = parser.parseDocument('[text](url)');
      expect(hasType(doc, MdNodeType.link), isTrue);
    });

    test('image', () {
      final doc = parser.parseDocument('![alt](src)');
      expect(hasType(doc, MdNodeType.image), isTrue);
    });
  });

  group('HTML Block', () {
    test('div html block', () {
      final doc = parser.parseDocument('<div>\ncontent\n</div>');
      expect(hasType(doc, MdNodeType.htmlBlock), isTrue);
    });

    test('comment block', () {
      final doc = parser.parseDocument('<!-- comment -->');
      expect(hasType(doc, MdNodeType.commentBlock), isTrue);
    });
  });

  group('Link Reference', () {
    test('link reference definition', () {
      final doc = parser.parseDocument('[label]: http://example.com');
      expect(hasType(doc, MdNodeType.linkReference), isTrue);
    });
  });

  group('Complex Documents', () {
    test('mixed content', () {
      final input = '''# Title

Some text with **bold** and *italic*.

- Item 1
- Item 2

> A blockquote

```dart
void main() {}
```

---''';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.atxHeading1), isTrue);
      expect(hasType(doc, MdNodeType.paragraph), isTrue);
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
      expect(hasType(doc, MdNodeType.emphasis), isTrue);
      expect(hasType(doc, MdNodeType.bulletList), isTrue);
      expect(hasType(doc, MdNodeType.blockquote), isTrue);
      expect(hasType(doc, MdNodeType.fencedCode), isTrue);
      expect(hasType(doc, MdNodeType.horizontalRule), isTrue);
    });
  });
}
