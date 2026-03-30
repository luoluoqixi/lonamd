import 'md_block_context.dart';
import 'md_element.dart';
import 'md_inline_context.dart';
import 'md_line.dart';
import 'md_node_type.dart';

// ===================== Strikethrough =====================

final _strikethroughDelim = MdDelimiterType(
  resolve: MdNodeType.strikethrough,
  mark: MdNodeType.strikethroughMark,
);

/// Punctuation regex matching Lezer's definition
final RegExp _punctuation = (() {
  try {
    return RegExp(r'[\p{S}|\p{P}]', unicode: true);
  } catch (_) {
    return RegExp(r'''[!"#$%&'()*+,\-.\/:;<=>?@\[\\\]^_`{|}~\xA1]''');
  }
})();

/// GFM strikethrough: ~~text~~
/// Follows the same flanking rules as emphasis.
int parseStrikethrough(MdInlineContext cx, int next, int pos) {
  if (next != 0x7E /* '~' */ ||
      cx.char(pos + 1) != 0x7E ||
      cx.char(pos + 2) == 0x7E) {
    return -1;
  }

  final before = cx.slice(pos - 1, pos);
  final after = cx.slice(pos + 2, pos + 3);
  final sBefore = before.isEmpty || RegExp(r'\s').hasMatch(before);
  final sAfter = after.isEmpty || RegExp(r'\s').hasMatch(after);
  final pBefore = _punctuation.hasMatch(before);
  final pAfter = _punctuation.hasMatch(after);

  return cx.addDelimiter(
    _strikethroughDelim,
    pos,
    pos + 2,
    !sAfter && (!pAfter || sBefore || pBefore),
    !sBefore && (!pBefore || sAfter || pAfter),
  );
}

// ===================== Highlight =====================

final _highlightDelim = MdDelimiterType(
  resolve: MdNodeType.highlight,
  mark: MdNodeType.highlightMark,
);

/// Highlight syntax: ==text==
/// Same flanking rules as emphasis/strikethrough.
int parseHighlight(MdInlineContext cx, int next, int pos) {
  if (next != 0x3D /* '=' */ ||
      cx.char(pos + 1) != 0x3D ||
      cx.char(pos + 2) == 0x3D) {
    return -1;
  }

  final before = cx.slice(pos - 1, pos);
  final after = cx.slice(pos + 2, pos + 3);
  final sBefore = before.isEmpty || RegExp(r'\s').hasMatch(before);
  final sAfter = after.isEmpty || RegExp(r'\s').hasMatch(after);
  final pBefore = _punctuation.hasMatch(before);
  final pAfter = _punctuation.hasMatch(after);

  return cx.addDelimiter(
    _highlightDelim,
    pos,
    pos + 2,
    !sAfter && (!pAfter || sBefore || pBefore),
    !sBefore && (!pBefore || sAfter || pAfter),
  );
}

// ===================== Table =====================

/// Check whether the line contains an unescaped pipe character.
bool _hasPipe(String str, int start) {
  for (int i = start; i < str.length; i++) {
    final next = str.codeUnitAt(i);
    if (next == 0x7C /* '|' */) return true;
    if (next == 0x5C /* '\\' */) i++;
  }
  return false;
}

/// Regex for the delimiter line between header and body.
final _delimiterLine = RegExp(r'^\|?(\s*:?-+:?\s*\|)+(\s*:?-+:?\s*)?$');

/// Parse a table row, returning the cell count.
/// When [elts] is provided, push syntax elements for cells and delimiters.
int _parseRow(
  MdBlockContext cx,
  String line,
  int startI,
  List<MdElement>? elts,
  int offset,
) {
  int count = 0;
  bool first = true;
  int cellStart = -1, cellEnd = -1;
  bool esc = false;

  void parseCell() {
    elts!.add(MdElement(
      MdNodeType.tableCell,
      offset + cellStart,
      offset + cellEnd,
      cx.parser
          .parseInline(line.substring(cellStart, cellEnd), offset + cellStart),
    ));
  }

  for (int i = startI; i < line.length; i++) {
    final next = line.codeUnitAt(i);
    if (next == 0x7C /* '|' */ && !esc) {
      if (!first || cellStart > -1) count++;
      first = false;
      if (elts != null) {
        if (cellStart > -1) parseCell();
        elts.add(
            MdElement(MdNodeType.tableDelimiter, i + offset, i + offset + 1));
      }
      cellStart = cellEnd = -1;
    } else if (esc || (next != 0x20 && next != 0x09)) {
      if (cellStart < 0) cellStart = i;
      cellEnd = i + 1;
    }
    esc = !esc && next == 0x5C /* '\\' */;
  }
  if (cellStart > -1) {
    count++;
    if (elts != null) parseCell();
  }
  return count;
}

/// Leaf block parser for GFM tables.
class _TableParser extends MdLeafBlockParser {
  /// null = haven't seen line 2, false = not a table, List = table rows parsed
  Object? rows;

  @override
  bool nextLine(MdBlockContext cx, MdLine line, MdLeafBlock leaf) {
    if (rows == null) {
      // Second line — decide if this is a table
      rows = false;
      if ((line.next == 0x2D /* '-' */ ||
              line.next == 0x3A /* ':' */ ||
              line.next == 0x7C /* '|' */) &&
          _delimiterLine.hasMatch(line.text.substring(line.pos))) {
        final lineText = line.text.substring(line.pos);
        final firstRow = <MdElement>[];
        final firstCount = _parseRow(cx, leaf.content, 0, firstRow, leaf.start);
        if (firstCount == _parseRow(cx, lineText, 0, null, 0)) {
          rows = <MdElement>[
            MdElement(MdNodeType.tableHeader, leaf.start,
                leaf.start + leaf.content.length, firstRow),
            MdElement(MdNodeType.tableDelimiter, cx.lineStart + line.pos,
                cx.lineStart + line.text.length),
          ];
        }
      }
    } else if (rows is List<MdElement>) {
      // Line after the second — add data row
      final content = <MdElement>[];
      _parseRow(cx, line.text, line.pos, content, cx.lineStart);
      (rows as List<MdElement>).add(MdElement(
        MdNodeType.tableRow,
        cx.lineStart + line.pos,
        cx.lineStart + line.text.length,
        content,
      ));
    }
    return false;
  }

  @override
  bool finish(MdBlockContext cx, MdLeafBlock leaf) {
    if (rows is! List<MdElement>) return false;
    final rowList = rows as List<MdElement>;
    cx.addLeafElement(
      leaf,
      MdElement(MdNodeType.table, leaf.start, leaf.start + leaf.content.length,
          rowList),
    );
    return true;
  }
}

/// Table block extension: leaf factory + endLeaf predicate.
MdLeafBlockParser? tableLeaf(MdBlockContext cx, MdLeafBlock leaf) {
  return _hasPipe(leaf.content, 0) ? _TableParser() : null;
}

bool tableEndLeaf(MdBlockContext cx, MdLine line, MdLeafBlock leaf) {
  if (leaf.parsers.any((p) => p is _TableParser) ||
      !_hasPipe(line.text, line.basePos)) {
    return false;
  }
  final next = cx.peekLine();
  return _delimiterLine.hasMatch(next) &&
      _parseRow(cx, line.text, line.basePos, null, 0) ==
          _parseRow(cx, next, line.basePos, null, 0);
}

// ===================== TaskList =====================

final _taskRE = RegExp(r'^\[[ xX]\][ \t]');

/// Leaf block parser for GFM task list items.
class _TaskParser extends MdLeafBlockParser {
  @override
  bool nextLine(MdBlockContext cx, MdLine line, MdLeafBlock leaf) => false;

  @override
  bool finish(MdBlockContext cx, MdLeafBlock leaf) {
    cx.addLeafElement(
      leaf,
      MdElement(MdNodeType.task, leaf.start, leaf.start + leaf.content.length, [
        MdElement(MdNodeType.taskMarker, leaf.start, leaf.start + 3),
        ...cx.parser.parseInline(leaf.content.substring(3), leaf.start + 3),
      ]),
    );
    return true;
  }
}

/// TaskList leaf factory: only triggers inside a ListItem context.
MdLeafBlockParser? taskLeaf(MdBlockContext cx, MdLeafBlock leaf) {
  if (!_taskRE.hasMatch(leaf.content)) return null;
  // Check parent is a ListItem
  for (int i = cx.stack.length - 1; i >= 0; i--) {
    if (cx.stack[i].type == MdNodeType.listItem) return _TaskParser();
  }
  return null;
}

// ===================== Autolink (GFM) =====================

final _autolinkRE =
    RegExp(r'(www\.)|(https?://)|([\w.+-]{1,100}@)|(mailto:|xmpp:)');
final _urlRE = RegExp(r'[\w-]+(\.[\w-]+)+(\/[^\s<]*)?');
final _lastTwoDomainWords = RegExp(r'[\w-]+\.[\w-]+($|\/)');
final _emailRE = RegExp(r'[\w.+-]+@[\w-]+(\.[\w.-]+)+');
final _xmppResourceRE = RegExp(r'\/[a-zA-Z\d@.]+');

int _count(String str, int from, int to, int ch) {
  int result = 0;
  for (int i = from; i < to; i++) {
    if (str.codeUnitAt(i) == ch) result++;
  }
  return result;
}

int _autolinkURLEnd(String text, int from) {
  final m = _urlRE.matchAsPrefix(text, from);
  if (m == null) return -1;
  final domainMatch = _lastTwoDomainWords.firstMatch(m.group(0)!);
  if (domainMatch == null || domainMatch.group(0)!.contains('_')) return -1;
  int end = from + m.group(0)!.length;
  for (;;) {
    if (end <= from) break;
    final last = text.codeUnitAt(end - 1);
    if (last == 0x3F || // ?
        last == 0x21 || // !
        last == 0x2E || // .
        last == 0x2C || // ,
        last == 0x3A || // :
        last == 0x2A || // *
        last == 0x5F || // _
        last == 0x7E) {
      // ~
      end--;
    } else if (last == 0x29 /* ')' */ &&
        _count(text, from, end, 0x29) > _count(text, from, end, 0x28)) {
      end--;
    } else if (last == 0x3B /* ';' */) {
      final trailing = RegExp(r'&(?:#\d+|#x[a-f\d]+|\w+);$')
          .firstMatch(text.substring(from, end));
      if (trailing != null) {
        end = from + trailing.start;
      } else {
        break;
      }
    } else {
      break;
    }
  }
  return end;
}

int _autolinkEmailEnd(String text, int from) {
  final m = _emailRE.matchAsPrefix(text, from);
  if (m == null) return -1;
  final str = m.group(0)!;
  final last = str[str.length - 1];
  if (last == '_' || last == '-') return -1;
  return from + str.length - (last == '.' ? 1 : 0);
}

/// GFM autolink detection for www., http://, mailto:, xmpp:, and email.
int parseAutolink(MdInlineContext cx, int next, int absPos) {
  final cxi = cx as MdInlineContextImpl;
  final pos = absPos - cx.offset;
  // Don't match inside a word
  if (pos > 0 && RegExp(r'\w').hasMatch(cx.text[pos - 1])) return -1;

  final m = _autolinkRE.matchAsPrefix(cx.text, pos);
  if (m == null) return -1;

  int end = -1;
  if (m.group(1) != null || m.group(2) != null) {
    // www. or http://
    end = _autolinkURLEnd(cx.text, pos + m.group(0)!.length);
    if (end > -1 && cxi.hasOpenLink) {
      final noBracket =
          RegExp(r'([^\[\]]|\[[^\]]*\])*').matchAsPrefix(cx.text, pos);
      if (noBracket != null) {
        end = pos + noBracket.group(0)!.length;
      }
    }
  } else if (m.group(3) != null) {
    // email address
    end = _autolinkEmailEnd(cx.text, pos);
  } else {
    // mailto: or xmpp:
    end = _autolinkEmailEnd(cx.text, pos + m.group(0)!.length);
    if (end > -1 && m.group(0) == 'xmpp:') {
      final xm = _xmppResourceRE.matchAsPrefix(cx.text, end);
      if (xm != null) end = xm.start + xm.group(0)!.length;
    }
  }
  if (end < 0) return -1;
  cx.addElement(cx.elt(MdNodeType.url, absPos, end + cx.offset));
  return end + cx.offset;
}

// ===================== GFM Parser Factory =====================

/// Create a Markdown parser with GFM extensions
/// (Strikethrough, Table, TaskList, Autolink, Highlight).
MdMarkdownParserImpl gfmMarkdownParser() {
  final base = defaultMarkdownParser();

  // Insert Table leaf parser BEFORE SetextHeading (last element)
  // and TaskList leaf parser AFTER SetextHeading (at end)
  final leafParsers = List<MdLeafBlockParserFn?>.of(base.leafBlockParsers);
  // SetextHeading is the last entry — insert Table before it
  leafParsers.insert(leafParsers.length - 1, tableLeaf);
  // TaskList after SetextHeading
  leafParsers.add(taskLeaf);

  // Insert Table endLeaf at start (so it takes priority)
  final endLeaf = List<MdEndLeafFn>.of(base.endLeafBlock);
  endLeaf.insert(0, tableEndLeaf);

  // Append GFM inline parsers after emphasis
  final inlineParsers = List<MdInlineParserFn?>.of(base.inlineParsers);
  inlineParsers.addAll([
    parseStrikethrough,
    parseHighlight,
    parseAutolink,
  ]);

  return MdMarkdownParserImpl(
    blockParsers: base.blockParsers,
    leafBlockParsers: leafParsers,
    endLeafBlock: endLeaf,
    skipContextMarkup: base.skipContextMarkup,
    inlineParsers: inlineParsers,
  );
}
