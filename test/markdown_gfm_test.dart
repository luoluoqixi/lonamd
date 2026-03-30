import 'package:lonamd/src/markdown/md_block_context.dart';
import 'package:lonamd/src/markdown/md_element.dart';
import 'package:lonamd/src/markdown/md_extension.dart';
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

bool hasType(MdElement root, MdNodeType type) => collect(root, type).isNotEmpty;

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
    parser = gfmMarkdownParser();
  });

  // ===================== Strikethrough =====================

  group('Strikethrough', () {
    test('basic ~~text~~', () {
      final doc = parser.parseDocument('~~deleted~~');
      expect(hasType(doc, MdNodeType.strikethrough), isTrue);
      final marks = collect(doc, MdNodeType.strikethroughMark);
      expect(marks.length, 2);
    });

    test('strikethrough inside paragraph', () {
      final doc = parser.parseDocument('Hello ~~world~~ end');
      expect(hasType(doc, MdNodeType.strikethrough), isTrue);
      final st = collect(doc, MdNodeType.strikethrough).first;
      expect(st.from, 6);
      expect(st.to, 15);
    });

    test('~~~ three tildes should not match strikethrough', () {
      final doc = parser.parseDocument('~~~text~~~');
      expect(hasType(doc, MdNodeType.strikethrough), isFalse);
    });

    test('unmatched ~~ does not produce strikethrough', () {
      final doc = parser.parseDocument('~~no match');
      expect(hasType(doc, MdNodeType.strikethrough), isFalse);
    });

    test('strikethrough with emphasis inside', () {
      final doc = parser.parseDocument('~~**bold** deleted~~');
      expect(hasType(doc, MdNodeType.strikethrough), isTrue);
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
    });
  });

  // ===================== Highlight =====================

  group('Highlight', () {
    test('basic ==text==', () {
      final doc = parser.parseDocument('==highlighted==');
      expect(hasType(doc, MdNodeType.highlight), isTrue);
      final marks = collect(doc, MdNodeType.highlightMark);
      expect(marks.length, 2);
    });

    test('highlight inside paragraph', () {
      final doc = parser.parseDocument('Hello ==world== end');
      expect(hasType(doc, MdNodeType.highlight), isTrue);
      final hl = collect(doc, MdNodeType.highlight).first;
      expect(hl.from, 6);
      expect(hl.to, 15);
    });

    test('=== three equals still matches (unlike ~~~ which is fenced code)',
        () {
      // Unlike ~~~text~~~ which is consumed by the fenced code block parser,
      // ===text=== has no block-level handler, so the inline delimiter system
      // picks up == from within ===, producing a highlight.
      final doc = parser.parseDocument('===text===');
      expect(hasType(doc, MdNodeType.highlight), isTrue);
    });
  });

  // ===================== Table =====================

  group('Table', () {
    test('basic table', () {
      final input = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.table), isTrue);
      expect(hasType(doc, MdNodeType.tableHeader), isTrue);
      expect(hasType(doc, MdNodeType.tableRow), isTrue);
      expect(hasType(doc, MdNodeType.tableCell), isTrue);
      expect(hasType(doc, MdNodeType.tableDelimiter), isTrue);
    });

    test('table header cells match', () {
      final input = '| h1 | h2 |\n| --- | --- |\n| c1 | c2 |';
      final doc = parser.parseDocument(input);
      final cells = collect(doc, MdNodeType.tableCell);
      expect(cells.length, 4); // 2 header + 2 data
    });

    test('table with multiple rows', () {
      final input = '| a | b |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |\n| 5 | 6 |';
      final doc = parser.parseDocument(input);
      final rows = collect(doc, MdNodeType.tableRow);
      expect(rows.length, 3); // 3 data rows
    });

    test('table without leading pipe', () {
      final input = 'a | b\n--- | ---\n1 | 2';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.table), isTrue);
    });

    test('non-table when delimiter line missing', () {
      final input = '| a | b |\n| not dashes |';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.table), isFalse);
    });

    test('table with inline formatting in cells', () {
      final input = '| **bold** | *italic* |\n| --- | --- |\n| `code` | text |';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.table), isTrue);
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
      expect(hasType(doc, MdNodeType.emphasis), isTrue);
      expect(hasType(doc, MdNodeType.inlineCode), isTrue);
    });
  });

  // ===================== TaskList =====================

  group('TaskList', () {
    test('unchecked task', () {
      final doc = parser.parseDocument('- [ ] todo');
      expect(hasType(doc, MdNodeType.task), isTrue);
      expect(hasType(doc, MdNodeType.taskMarker), isTrue);
    });

    test('checked task [x]', () {
      final doc = parser.parseDocument('- [x] done');
      expect(hasType(doc, MdNodeType.task), isTrue);
    });

    test('checked task [X]', () {
      final doc = parser.parseDocument('- [X] Done');
      expect(hasType(doc, MdNodeType.task), isTrue);
    });

    test('task with inline content', () {
      final doc = parser.parseDocument('- [x] **bold** task');
      expect(hasType(doc, MdNodeType.task), isTrue);
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
    });

    test('not a task outside list', () {
      final doc = parser.parseDocument('[x] not a task');
      expect(hasType(doc, MdNodeType.task), isFalse);
    });

    test('multiple tasks', () {
      final doc =
          parser.parseDocument('- [ ] first\n- [x] second\n- [ ] third');
      final tasks = collect(doc, MdNodeType.task);
      expect(tasks.length, 3);
    });
  });

  // ===================== Autolink =====================

  group('Autolink (GFM)', () {
    test('www. link', () {
      final doc = parser.parseDocument('Visit www.example.com today');
      expect(hasType(doc, MdNodeType.url), isTrue);
    });

    test('http:// link', () {
      final doc = parser.parseDocument('See https://example.com/page');
      expect(hasType(doc, MdNodeType.url), isTrue);
    });

    test('email autolink', () {
      final doc = parser.parseDocument('Email user@example.com please');
      expect(hasType(doc, MdNodeType.url), isTrue);
    });

    test('no autolink inside word', () {
      final doc = parser.parseDocument('foowww.example.com');
      expect(hasType(doc, MdNodeType.url), isFalse);
    });
  });

  // ===================== Combined GFM =====================

  group('Combined GFM', () {
    test('strikethrough + table + task in one document', () {
      final input = '''# GFM Test

~~deleted~~

| a | b |
| --- | --- |
| 1 | 2 |

- [ ] todo
- [x] done

==highlight==''';
      final doc = parser.parseDocument(input);
      expect(hasType(doc, MdNodeType.atxHeading1), isTrue);
      expect(hasType(doc, MdNodeType.strikethrough), isTrue);
      expect(hasType(doc, MdNodeType.table), isTrue);
      expect(hasType(doc, MdNodeType.task), isTrue);
      expect(hasType(doc, MdNodeType.highlight), isTrue);
    });

    test('CommonMark features still work with GFM parser', () {
      final doc = parser.parseDocument(
          '# Title\n\nHello **world** and *italic*\n\n> quote\n\n- item');
      expect(hasType(doc, MdNodeType.atxHeading1), isTrue);
      expect(hasType(doc, MdNodeType.strongEmphasis), isTrue);
      expect(hasType(doc, MdNodeType.emphasis), isTrue);
      expect(hasType(doc, MdNodeType.blockquote), isTrue);
      expect(hasType(doc, MdNodeType.bulletList), isTrue);
    });
  });
}
