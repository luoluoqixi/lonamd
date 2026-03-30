import 'md_element.dart';
import 'md_inline_context.dart';
import 'md_line.dart';
import 'md_node_type.dart';

// ===================== Block Detection Functions =====================

int _isFencedCode(MdLine line) {
  if (line.next != 0x60 /* '`' */ && line.next != 0x7E /* '~' */) return -1;
  int pos = line.pos + 1;
  while (pos < line.text.length && line.text.codeUnitAt(pos) == line.next) {
    pos++;
  }
  if (pos < line.pos + 3) return -1;
  // For backtick fences, no backticks allowed in info string
  if (line.next == 0x60) {
    for (int i = pos; i < line.text.length; i++) {
      if (line.text.codeUnitAt(i) == 0x60) return -1;
    }
  }
  return pos;
}

int _isBlockquote(MdLine line) {
  if (line.next != 0x3E /* '>' */) return -1;
  return (line.pos + 1 < line.text.length &&
          line.text.codeUnitAt(line.pos + 1) == 0x20)
      ? 2
      : 1;
}

int _isHorizontalRule(MdLine line, MdBlockContext cx, bool breaking) {
  if (line.next != 0x2A /* '*' */ &&
      line.next != 0x2D /* '-' */ &&
      line.next != 0x5F /* '_' */) return -1;
  int count = 1;
  for (int pos = line.pos + 1; pos < line.text.length; pos++) {
    final ch = line.text.codeUnitAt(pos);
    if (ch == line.next) {
      count++;
    } else if (!_isSpace(ch)) {
      return -1;
    }
  }
  // Setext headings take precedence over horizontal rules with '-'
  if (breaking &&
      line.next == 0x2D &&
      _isSetextUnderline(line) > -1 &&
      line.depth == cx.stack.length) {
    return -1;
  }
  return count < 3 ? -1 : 1;
}

int _isAtxHeading(MdLine line) {
  if (line.next != 0x23 /* '#' */) return -1;
  int pos = line.pos + 1;
  while (pos < line.text.length && line.text.codeUnitAt(pos) == 0x23) pos++;
  if (pos < line.text.length && line.text.codeUnitAt(pos) != 0x20) return -1;
  final size = pos - line.pos;
  return size > 6 ? -1 : size;
}

int _isSetextUnderline(MdLine line) {
  if (line.next != 0x2D /* '-' */ && line.next != 0x3D /* '=' */) return -1;
  if (line.indent >= line.baseIndent + 4) return -1;
  int pos = line.pos + 1;
  while (pos < line.text.length && line.text.codeUnitAt(pos) == line.next) {
    pos++;
  }
  final end = pos;
  while (pos < line.text.length && _isSpace(line.text.codeUnitAt(pos))) pos++;
  return pos == line.text.length ? end : -1;
}

bool _inList(MdBlockContext cx, MdNodeType type) {
  for (int i = cx.stack.length - 1; i >= 0; i--) {
    if (cx.stack[i].type == type) return true;
  }
  return false;
}

int _isBulletList(MdLine line, MdBlockContext cx, bool breaking) {
  if (line.next != 0x2D /* '-' */ &&
      line.next != 0x2B /* '+' */ &&
      line.next != 0x2A /* '*' */) return -1;
  if (line.pos < line.text.length - 1 &&
      !_isSpace(line.text.codeUnitAt(line.pos + 1))) return -1;
  if (line.pos == line.text.length - 1 ||
      _isSpace(line.text.codeUnitAt(line.pos + 1))) {
    if (!breaking ||
        _inList(cx, MdNodeType.bulletList) ||
        line.skipSpace(line.text, line.pos + 2) < line.text.length) {
      return 1;
    }
  }
  return -1;
}

int _isOrderedList(MdLine line, MdBlockContext cx, bool breaking) {
  int pos = line.pos;
  int next = line.next;
  for (;;) {
    if (next >= 0x30 && next <= 0x39 /* '0'-'9' */) {
      pos++;
    } else {
      break;
    }
    if (pos == line.text.length) return -1;
    next = line.text.codeUnitAt(pos);
  }
  if (pos == line.pos ||
      pos > line.pos + 9 ||
      (next != 0x2E /* '.' */ && next != 0x29 /* ')' */) ||
      (pos < line.text.length - 1 && !_isSpace(line.text.codeUnitAt(pos + 1))))
    return -1;
  if (breaking &&
      !_inList(cx, MdNodeType.orderedList) &&
      (line.skipSpace(line.text, pos + 1) == line.text.length ||
          pos > line.pos + 1 ||
          line.next != 0x31 /* '1' */)) return -1;
  return pos + 1 - line.pos;
}

int _isHTMLBlock(MdLine line, MdBlockContext cx, bool breaking) {
  if (line.next != 0x3C /* '<' */) return -1;
  final rest = line.text.substring(line.pos);
  for (int i = 0; i < _htmlBlockStyle.length - (breaking ? 1 : 0); i++) {
    if (_htmlBlockStyle[i].open.hasMatch(rest)) return i;
  }
  return -1;
}

final _emptyLine = RegExp(r'^[ \t]*$');
final _commentEnd = RegExp(r'-->');
final _processingEnd = RegExp(r'\?>');

class _HtmlBlockDef {
  final RegExp open;
  final RegExp close;
  _HtmlBlockDef(this.open, this.close);
}

final _htmlBlockStyle = <_HtmlBlockDef>[
  _HtmlBlockDef(
      RegExp(r'^<(?:script|pre|style)(?:\s|>|$)', caseSensitive: false),
      RegExp(r'<\/(?:script|pre|style)>', caseSensitive: false)),
  _HtmlBlockDef(RegExp(r'^\s*<!--'), _commentEnd),
  _HtmlBlockDef(RegExp(r'^\s*<\?'), _processingEnd),
  _HtmlBlockDef(RegExp(r'^\s*<![A-Z]'), RegExp(r'>')),
  _HtmlBlockDef(RegExp(r'^\s*<!\[CDATA\['), RegExp(r'\]\]>')),
  _HtmlBlockDef(
      RegExp(
          r'^\s*<\/?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:\s|\/?>|$)',
          caseSensitive: false),
      _emptyLine),
  _HtmlBlockDef(
      RegExp(
          r'^\s*(?:<\/[a-z][\w-]*\s*>|<[a-z][\w-]*(\s+[a-z:_][\w-.]*(?:\s*=\s*(?:[^\s"'
          "'"
          r'=<>`]+|'
          "'"
          r"[^']*'"
          r'|"[^"]*"))?)*\s*>)\s*$',
          caseSensitive: false),
      _emptyLine),
];

int _getListIndent(MdLine line, int pos) {
  final indentAfter = line.countIndent(pos, line.pos, line.indent);
  final indented =
      line.countIndent(line.skipSpace(line.text, pos), pos, indentAfter);
  return indented >= indentAfter + 5 ? indentAfter + 1 : indented;
}

void _addCodeText(List<MdElement> marks, int from, int to) {
  if (marks.isNotEmpty &&
      marks.last.to == from &&
      marks.last.type == MdNodeType.codeText) {
    marks.last.to = to;
  } else {
    marks.add(MdElement(MdNodeType.codeText, from, to));
  }
}

bool _isSpace(int ch) => ch == 32 || ch == 9 || ch == 10 || ch == 13;

// ===================== Default Skip Markup =====================

bool _skipBlockquote(MdCompositeBlock bl, MdBlockContext cx, MdLine line) {
  if (line.next != 0x3E /* '>' */) return false;
  line.addMarker(MdElement(MdNodeType.quoteMark, cx.lineStart + line.pos,
      cx.lineStart + line.pos + 1));
  line.moveBase(
      line.pos + (_isSpace(line.text.codeUnitAt(line.pos + 1)) ? 2 : 1));
  bl.end = cx.lineStart + line.text.length;
  return true;
}

bool _skipListItem(MdCompositeBlock bl, MdBlockContext cx, MdLine line) {
  if (line.indent < line.baseIndent + bl.value && line.next > -1) return false;
  line.moveBaseColumn(line.baseIndent + bl.value);
  return true;
}

bool _skipForList(MdCompositeBlock bl, MdBlockContext cx, MdLine line) {
  if (line.pos == line.text.length ||
      (bl != cx.block &&
          line.indent >= cx.stack[line.depth + 1].value + line.baseIndent))
    return true;
  if (line.indent >= line.baseIndent + 4) return false;
  final size = (bl.type == MdNodeType.orderedList
      ? _isOrderedList(line, cx, false)
      : _isBulletList(line, cx, false));
  return size > 0 &&
      (bl.type != MdNodeType.bulletList ||
          _isHorizontalRule(line, cx, false) < 0) &&
      line.text.codeUnitAt(line.pos + size - 1) == bl.value;
}

bool _skipDocument(MdCompositeBlock bl, MdBlockContext cx, MdLine line) {
  return true;
}

// ===================== Default Block Parsers =====================

MdBlockResult _parseIndentedCode(MdBlockContext cx, MdLine line) {
  final base = line.baseIndent + 4;
  if (line.indent < base) return MdBlockResult.none;
  final start = line.findColumn(base);
  int from = cx.lineStart + start;
  int to = cx.lineStart + line.text.length;
  final marks = <MdElement>[];
  final pendingMarks = <MdElement>[];
  _addCodeText(marks, from, to);

  while (cx.nextLine() && line.depth >= cx.stack.length) {
    if (line.pos == line.text.length) {
      // Empty line
      _addCodeText(pendingMarks, cx.lineStart - 1, cx.lineStart);
      for (final m in line.markers) pendingMarks.add(m);
    } else if (line.indent < base) {
      break;
    } else {
      if (pendingMarks.isNotEmpty) {
        for (final m in pendingMarks) {
          if (m.type == MdNodeType.codeText) {
            _addCodeText(marks, m.from, m.to);
          } else {
            marks.add(m);
          }
        }
        pendingMarks.clear();
      }
      _addCodeText(marks, cx.lineStart - 1, cx.lineStart);
      for (final m in line.markers) marks.add(m);
      to = cx.lineStart + line.text.length;
      final codeStart = cx.lineStart + line.findColumn(line.baseIndent + 4);
      if (codeStart < to) _addCodeText(marks, codeStart, to);
    }
  }
  if (pendingMarks.isNotEmpty) {
    final filtered =
        pendingMarks.where((m) => m.type != MdNodeType.codeText).toList();
    if (filtered.isNotEmpty) {
      line.markers = filtered + line.markers;
    }
  }

  cx.addElement(MdElement(MdNodeType.codeBlock, from, to, marks));
  return MdBlockResult.leaf;
}

MdBlockResult _parseFencedCode(MdBlockContext cx, MdLine line) {
  final fenceEnd = _isFencedCode(line);
  if (fenceEnd < 0) return MdBlockResult.none;

  final from = cx.lineStart + line.pos;
  final ch = line.next;
  final len = fenceEnd - line.pos;
  final infoFrom = skipSpaceGlobal(line.text, fenceEnd);
  final infoTo = skipSpaceBack(line.text, line.text.length, infoFrom);
  final marks = <MdElement>[
    MdElement(MdNodeType.codeMark, from, from + len),
  ];
  if (infoFrom < infoTo) {
    marks.add(MdElement(
      MdNodeType.codeInfo,
      cx.lineStart + infoFrom,
      cx.lineStart + infoTo,
    ));
  }

  bool first = true;
  while (cx.nextLine() && line.depth >= cx.stack.length) {
    int i = line.pos;
    if (line.indent - line.baseIndent < 4) {
      while (i < line.text.length && line.text.codeUnitAt(i) == ch) i++;
    }
    if (i - line.pos >= len &&
        line.skipSpace(line.text, i) == line.text.length) {
      // Closing fence
      for (final m in line.markers) marks.add(m);
      marks.add(MdElement(
          MdNodeType.codeMark, cx.lineStart + line.pos, cx.lineStart + i));
      cx.nextLine();
      break;
    } else {
      if (!first) _addCodeText(marks, cx.lineStart - 1, cx.lineStart);
      for (final m in line.markers) marks.add(m);
      final textStart = cx.lineStart + line.basePos;
      final textEnd = cx.lineStart + line.text.length;
      if (textStart < textEnd) _addCodeText(marks, textStart, textEnd);
    }
    first = false;
  }

  cx.addElement(
      MdElement(MdNodeType.fencedCode, from, cx.prevLineEnd(), marks));
  return MdBlockResult.leaf;
}

MdBlockResult _parseBlockquote(MdBlockContext cx, MdLine line) {
  final size = _isBlockquote(line);
  if (size < 0) return MdBlockResult.none;
  cx.startContext(MdNodeType.blockquote, line.pos);
  cx.addNode(MdNodeType.quoteMark, cx.lineStart + line.pos,
      cx.lineStart + line.pos + 1);
  line.moveBase(line.pos + size);
  return MdBlockResult.context;
}

MdBlockResult _parseHorizontalRule(MdBlockContext cx, MdLine line) {
  if (_isHorizontalRule(line, cx, false) < 0) return MdBlockResult.none;
  final from = cx.lineStart + line.pos;
  cx.nextLine();
  cx.addNode(MdNodeType.horizontalRule, from);
  return MdBlockResult.leaf;
}

MdBlockResult _parseBulletList(MdBlockContext cx, MdLine line) {
  final size = _isBulletList(line, cx, false);
  if (size < 0) return MdBlockResult.none;
  if (cx.block.type != MdNodeType.bulletList) {
    cx.startContext(MdNodeType.bulletList, line.basePos, line.next);
  }
  final newBase = _getListIndent(line, line.pos + 1);
  cx.startContext(MdNodeType.listItem, line.basePos, newBase - line.baseIndent);
  cx.addNode(MdNodeType.listMark, cx.lineStart + line.pos,
      cx.lineStart + line.pos + size);
  line.moveBaseColumn(newBase);
  return MdBlockResult.context;
}

MdBlockResult _parseOrderedList(MdBlockContext cx, MdLine line) {
  final size = _isOrderedList(line, cx, false);
  if (size < 0) return MdBlockResult.none;
  if (cx.block.type != MdNodeType.orderedList) {
    cx.startContext(MdNodeType.orderedList, line.basePos,
        line.text.codeUnitAt(line.pos + size - 1));
  }
  final newBase = _getListIndent(line, line.pos + size);
  cx.startContext(MdNodeType.listItem, line.basePos, newBase - line.baseIndent);
  cx.addNode(MdNodeType.listMark, cx.lineStart + line.pos,
      cx.lineStart + line.pos + size);
  line.moveBaseColumn(newBase);
  return MdBlockResult.context;
}

MdBlockResult _parseATXHeading(MdBlockContext cx, MdLine line) {
  final size = _isAtxHeading(line);
  if (size < 0) return MdBlockResult.none;

  final off = line.pos;
  final from = cx.lineStart + off;
  int endOfSpace = skipSpaceBack(line.text, line.text.length, off);
  int after = endOfSpace;
  while (after > off && line.text.codeUnitAt(after - 1) == line.next) {
    after--;
  }
  if (after == endOfSpace ||
      after == off ||
      !_isSpace(line.text.codeUnitAt(after - 1))) {
    after = line.text.length;
  }

  // Parse inline content between heading marks
  final inlineText = line.text.substring(off + size + 1, after);
  final inlineElements = cx.parser.parseInline(inlineText, from + size + 1);

  final children = <MdElement>[
    MdElement(MdNodeType.headerMark, from, from + size),
    ...inlineElements,
  ];
  if (after < line.text.length) {
    children.add(MdElement(MdNodeType.headerMark, cx.lineStart + after,
        cx.lineStart + endOfSpace));
  }

  final headingType = MdNodeType.atxHeading(size);
  cx.nextLine();
  cx.addElement(
      MdElement(headingType, from, from + line.text.length - off, children));
  return MdBlockResult.leaf;
}

MdBlockResult _parseHTMLBlock(MdBlockContext cx, MdLine line) {
  final type = _isHTMLBlock(line, cx, false);
  if (type < 0) return MdBlockResult.none;
  final from = cx.lineStart + line.pos;
  final end = _htmlBlockStyle[type].close;
  final marks = <MdElement>[];
  bool trailing = end != _emptyLine;

  while (!end.hasMatch(line.text) && cx.nextLine()) {
    if (line.depth < cx.stack.length) {
      trailing = false;
      break;
    }
    for (final m in line.markers) marks.add(m);
  }
  if (trailing) cx.nextLine();

  final nodeType = end == _commentEnd
      ? MdNodeType.commentBlock
      : end == _processingEnd
          ? MdNodeType.processingInstructionBlock
          : MdNodeType.htmlBlock;
  cx.addElement(MdElement(nodeType, from, cx.prevLineEnd(), marks));
  return MdBlockResult.leaf;
}

// ===================== Leaf Block Parsers =====================

class _SetextHeadingParser implements MdLeafBlockParser {
  @override
  bool nextLine(MdBlockContext cx, MdLine line, MdLeafBlock leaf) {
    final cxi = cx as MdBlockContextImpl;
    final underline =
        line.depth < cxi.stack.length ? -1 : _isSetextUnderline(line);
    if (underline < 0) return false;
    final next = line.next;
    final underlineMark = MdElement(MdNodeType.headerMark,
        cxi.lineStart + line.pos, cxi.lineStart + underline);
    cxi.nextLine();
    final headingType =
        next == 0x3D ? MdNodeType.setextHeading1 : MdNodeType.setextHeading2;
    final inlineElements = cxi.parser.parseInline(leaf.content, leaf.start);
    cx.addLeafElement(
      leaf,
      MdElement(headingType, leaf.start, cx.prevLineEnd(),
          [...inlineElements, underlineMark]),
    );
    return true;
  }

  @override
  bool finish(MdBlockContext cx, MdLeafBlock leaf) => false;
}

class _LinkReferenceParser implements MdLeafBlockParser {
  int _stage = 0; // 0=Start, 1=Label, 2=Link, 3=Title, -1=Failed
  List<MdElement> _elts = [];
  int _pos = 0;
  int _start;

  _LinkReferenceParser(MdLeafBlock leaf) : _start = leaf.start {
    _advance(leaf.content);
  }

  @override
  bool nextLine(MdBlockContext cx, MdLine line, MdLeafBlock leaf) {
    if (_stage == -1) return false;
    final content = '${leaf.content}\n${line.scrub()}';
    final finish = _advance(content);
    if (finish > -1 && finish < content.length) {
      return _complete(cx as MdBlockContextImpl, leaf, finish);
    }
    return false;
  }

  @override
  bool finish(MdBlockContext cx, MdLeafBlock leaf) {
    if ((_stage == 2 || _stage == 3) &&
        skipSpaceGlobal(leaf.content, _pos) == leaf.content.length) {
      return _complete(cx as MdBlockContextImpl, leaf, leaf.content.length);
    }
    return false;
  }

  bool _complete(MdBlockContextImpl cx, MdLeafBlock leaf, int len) {
    cx.addLeafElement(
        leaf, MdElement(MdNodeType.linkReference, _start, _start + len, _elts));
    return true;
  }

  int _advance(String content) {
    for (;;) {
      if (_stage == -1) {
        return -1;
      } else if (_stage == 0) {
        // Start: look for [label]
        final label = _parseLinkLabelRef(content, _pos, _start, true);
        if (label == null) {
          _stage = -1;
          return -1;
        }
        _pos = label.to - _start;
        _elts.add(label);
        _stage = 1;
        if (_pos >= content.length ||
            content.codeUnitAt(_pos) != 0x3A /* ':' */) {
          _stage = -1;
          return -1;
        }
        _elts.add(
            MdElement(MdNodeType.linkMark, _pos + _start, _pos + _start + 1));
        _pos++;
      } else if (_stage == 1) {
        // Label done, look for URL
        final url =
            _parseURLRef(content, skipSpaceGlobal(content, _pos), _start);
        if (url == null) {
          _stage = -1;
          return -1;
        }
        _pos = url.to - _start;
        _elts.add(url);
        _stage = 2;
      } else if (_stage == 2) {
        // URL done, optionally look for title
        final skip = skipSpaceGlobal(content, _pos);
        int end = 0;
        if (skip > _pos) {
          final title = _parseLinkTitleRef(content, skip, _start);
          if (title != null) {
            final titleEnd = _lineEnd(content, title.to - _start);
            if (titleEnd > 0) {
              _elts.add(title);
              _pos = title.to - _start;
              _stage = 3;
              end = titleEnd;
            }
          }
        }
        if (end == 0) end = _lineEnd(content, _pos);
        return end > 0 && end < content.length ? end : -1;
      } else {
        // Title stage
        return _lineEnd(content, _pos);
      }
    }
  }

  int _lineEnd(String text, int pos) {
    for (; pos < text.length; pos++) {
      final next = text.codeUnitAt(pos);
      if (next == 0x0A) break;
      if (!_isSpace(next)) return -1;
    }
    return pos;
  }

  MdElement? _parseLinkLabelRef(
      String text, int start, int offset, bool requireNonWS) {
    bool escaped = false;
    for (int pos = start + 1; pos < text.length && pos < start + 1000; pos++) {
      final ch = text.codeUnitAt(pos);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == 0x5D) {
        return requireNonWS
            ? null
            : MdElement(MdNodeType.linkLabel, start + offset, pos + 1 + offset);
      }
      if (requireNonWS && !_isSpace(ch)) requireNonWS = false;
      if (ch == 0x5B) return null;
      if (ch == 0x5C) escaped = true;
    }
    return null;
  }

  MdElement? _parseURLRef(String text, int start, int offset) {
    if (start >= text.length) return null;
    final next = text.codeUnitAt(start);
    if (next == 0x3C) {
      for (int pos = start + 1; pos < text.length; pos++) {
        final ch = text.codeUnitAt(pos);
        if (ch == 0x3E) {
          return MdElement(MdNodeType.url, start + offset, pos + 1 + offset);
        }
        if (ch == 0x3C || ch == 0x0A) return null;
      }
      return null;
    } else {
      int depth = 0, pos = start;
      bool escaped = false;
      for (; pos < text.length; pos++) {
        final ch = text.codeUnitAt(pos);
        if (_isSpace(ch)) break;
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == 0x28) {
          depth++;
        } else if (ch == 0x29) {
          if (depth == 0) break;
          depth--;
        } else if (ch == 0x5C) {
          escaped = true;
        }
      }
      return pos > start
          ? MdElement(MdNodeType.url, start + offset, pos + offset)
          : null;
    }
  }

  MdElement? _parseLinkTitleRef(String text, int start, int offset) {
    if (start >= text.length) return null;
    final next = text.codeUnitAt(start);
    if (next != 0x27 && next != 0x22 && next != 0x28) return null;
    final end = next == 0x28 ? 0x29 : next;
    for (int pos = start + 1; pos < text.length; pos++) {
      final ch = text.codeUnitAt(pos);
      if (ch == 0x5C) {
        pos++;
        continue;
      }
      if (ch == end) {
        return MdElement(
            MdNodeType.linkTitle, start + offset, pos + 1 + offset);
      }
    }
    return null;
  }
}

// ===================== Default EndLeaf Predicates =====================

final List<MdEndLeafFn> _defaultEndLeaf = [
  (cx, line, _) => _isAtxHeading(line) >= 0,
  (cx, line, _) => _isFencedCode(line) >= 0,
  (cx, line, _) => _isBlockquote(line) >= 0,
  (cx, line, _) => _isBulletList(line, cx as MdBlockContextImpl, true) >= 0,
  (cx, line, _) => _isOrderedList(line, cx as MdBlockContextImpl, true) >= 0,
  (cx, line, _) => _isHorizontalRule(line, cx as MdBlockContextImpl, true) >= 0,
  (cx, line, _) => _isHTMLBlock(line, cx as MdBlockContextImpl, true) >= 0,
];

// ===================== BlockContext Implementation =====================

/// The main block-level parsing context.
///
/// Implements the core parsing loop following Lezer's BlockContext.advance().
class MdBlockContextImpl implements MdBlockContext {
  @override
  final MdMarkdownParserImpl parser;

  final String input;

  @override
  late MdCompositeBlock block;

  @override
  late List<MdCompositeBlock> stack;

  @override
  final MdLine line = MdLine();

  bool _atEnd = false;

  @override
  int lineStart = 0;

  int _absoluteLineEnd = 0;

  MdBlockContextImpl(this.parser, this.input) {
    block = MdCompositeBlock.create(MdNodeType.document, 0, 0, 0, 0);
    stack = [block];
    _readLine();
  }

  /// Get the end position of the previous line
  @override
  int prevLineEnd() => _atEnd ? lineStart : lineStart - 1;

  /// Move to the next input line
  @override
  bool nextLine() {
    lineStart += line.text.length;
    if (_absoluteLineEnd >= input.length) {
      _atEnd = true;
      _readLine();
      return false;
    } else {
      lineStart++;
      _readLine();
      return true;
    }
  }

  @override
  String peekLine() {
    final start = _absoluteLineEnd + 1;
    if (start >= input.length) return '';
    final eol = input.indexOf('\n', start);
    return eol < 0 ? input.substring(start) : input.substring(start, eol);
  }

  /// Read the next line and process composite context markup
  void _readLine() {
    // Find line boundaries
    final start = lineStart;
    final eol = input.indexOf('\n', start);
    final text = eol < 0 ? input.substring(start) : input.substring(start, eol);
    _absoluteLineEnd = start + text.length;

    line.reset(text);

    // Let each active composite block skip its markup
    for (; line.depth < stack.length; line.depth++) {
      final cx = stack[line.depth];
      final handler = parser.skipContextMarkup[cx.type.id];
      if (handler == null) break;
      if (!handler(cx, this, line)) break;
      line.forward();
    }
  }

  @override
  void startContext(MdNodeType type, int start, [int value = 0]) {
    block = MdCompositeBlock.create(type, value, lineStart + start, block.hash,
        lineStart + line.text.length);
    stack.add(block);
  }

  @override
  void finishContext() {
    final cx = stack.removeLast();
    final top = stack.last;
    top.addChild(cx.toElement(), cx.from - top.from);
    block = top;
  }

  @override
  void addNode(MdNodeType type, int from, [int? to]) {
    block.addChild(
        MdElement(type, from, to ?? prevLineEnd()), from - block.from);
  }

  @override
  void addElement(MdElement elt) {
    block.addChild(elt, elt.from - block.from);
  }

  @override
  void addLeafElement(MdLeafBlock leaf, MdElement elt) {
    // Inject any composite block marks into the element's children
    final children = _injectMarks(elt.children.toList(), leaf.marks);
    addElement(MdElement(elt.type, elt.from, elt.to, children));
  }

  /// Finalize a leaf block (paragraph or custom handler result)
  void _finishLeaf(MdLeafBlock leaf) {
    for (final parser in leaf.parsers) {
      if (parser.finish(this, leaf)) return;
    }
    // Default: parse inline and create paragraph
    final inline = _injectMarks(
        this.parser.parseInline(leaf.content, leaf.start), leaf.marks);
    addElement(MdElement(MdNodeType.paragraph, leaf.start,
        leaf.start + leaf.content.length, inline));
  }

  /// The main parsing loop. Returns the document element.
  MdElement parse() {
    for (;;) {
      // 1. Flush composite block markers and close finished contexts,
      //    then advance through empty lines.
      for (;;) {
        for (int markI = 0;;) {
          final MdCompositeBlock? next =
              line.depth < stack.length ? stack.last : null;
          while (markI < line.markers.length &&
              (next == null || line.markers[markI].from < next.end)) {
            final mark = line.markers[markI++];
            addNode(mark.type, mark.from, mark.to);
          }
          if (next == null) break;
          finishContext();
        }
        if (line.pos < line.text.length) break;
        // Empty line — advance and flush again
        if (!nextLine()) return _finish();
      }

      // 2. Try block parsers. When a context is opened, re-run block
      //    parsers on the same line WITHOUT going back to flush.
      bool parsedLeaf = false;
      blockParsers:
      for (;;) {
        bool contextOpened = false;
        for (final bp in parser.blockParsers) {
          if (bp == null) continue;
          final result = bp(this, line);
          if (result == MdBlockResult.leaf) {
            parsedLeaf = true;
            break;
          }
          if (result == MdBlockResult.context) {
            line.forward();
            contextOpened = true;
            break; // break inner for, continue blockParsers
          }
        }
        if (parsedLeaf || !contextOpened) break blockParsers;
      }
      if (parsedLeaf) continue; // back to flush for next content

      // 3. Start leaf block (paragraph)
      final leaf =
          MdLeafBlock(lineStart + line.pos, line.text.substring(line.pos));
      for (final parse in parser.leafBlockParsers) {
        if (parse == null) continue;
        final p = parse(this, leaf);
        if (p != null) leaf.parsers.add(p);
      }

      // 4. Accumulate lines until leaf ends
      bool leafDone = false;
      while (nextLine()) {
        if (line.pos == line.text.length) break; // Empty line ends leaf
        if (line.indent < line.baseIndent + 4) {
          bool stopped = false;
          for (final stop in parser.endLeafBlock) {
            if (stop(this, line, leaf)) {
              stopped = true;
              break;
            }
          }
          if (stopped) break;
        }
        for (final p in leaf.parsers) {
          if (p.nextLine(this, line, leaf)) {
            leafDone = true;
            break;
          }
        }
        if (leafDone) break;
        leaf.content += '\n${line.scrub()}';
        for (final m in line.markers) leaf.marks.add(m);
      }
      if (!leafDone) _finishLeaf(leaf);
    }
  }

  MdElement _finish() {
    while (stack.length > 1) finishContext();
    return block.toElement(lineStart);
  }
}

List<MdElement> _injectMarks(List<MdElement> elements, List<MdElement> marks) {
  if (marks.isEmpty) return elements;
  if (elements.isEmpty) return marks;
  final elts = List<MdElement>.of(elements);
  int eI = 0;
  for (final mark in marks) {
    while (eI < elts.length && elts[eI].to < mark.to) eI++;
    if (eI < elts.length && elts[eI].from < mark.from) {
      final e = elts[eI];
      elts[eI] = MdElement(
          e.type, e.from, e.to, _injectMarks(e.children.toList(), [mark]));
    } else {
      elts.insert(eI++, mark);
    }
  }
  return elts;
}

// ===================== Parser Configuration =====================

/// The complete Markdown parser, mirroring @lezer/markdown's MarkdownParser.
class MdMarkdownParserImpl implements MdMarkdownParser {
  @override
  final List<MdBlockParserFn?> blockParsers;

  @override
  final List<MdLeafBlockParserFn?> leafBlockParsers;

  @override
  final List<MdEndLeafFn> endLeafBlock;

  @override
  final Map<int, MdSkipMarkupFn> skipContextMarkup;

  @override
  final List<MdInlineParserFn?> inlineParsers;

  MdMarkdownParserImpl({
    required this.blockParsers,
    required this.leafBlockParsers,
    required this.endLeafBlock,
    required this.skipContextMarkup,
    required this.inlineParsers,
  });

  @override
  List<MdElement> parseInline(String text, int offset) {
    final cx = MdInlineContextImpl(this, text, offset);
    int pos = offset;
    outer:
    while (pos < cx.end) {
      final next = cx.char(pos);
      for (final parser in inlineParsers) {
        if (parser == null) continue;
        final result = parser(cx, next, pos);
        if (result >= 0) {
          pos = result;
          continue outer;
        }
      }
      pos++;
    }
    return cx.resolveMarkers(0);
  }

  /// Parse a Markdown document and return the root element.
  MdElement parseDocument(String input) {
    final cx = MdBlockContextImpl(this, input);
    return cx.parse();
  }
}

/// Create the default CommonMark parser.
MdMarkdownParserImpl defaultMarkdownParser() {
  return MdMarkdownParserImpl(
    blockParsers: [
      null, // LinkReference placeholder (leaf only)
      _parseIndentedCode,
      _parseFencedCode,
      _parseBlockquote,
      _parseHorizontalRule,
      _parseBulletList,
      _parseOrderedList,
      _parseATXHeading,
      _parseHTMLBlock,
      null, // SetextHeading placeholder (leaf only)
    ],
    leafBlockParsers: [
      // LinkReference
      (cx, leaf) => leaf.content.codeUnitAt(0) == 0x5B
          ? _LinkReferenceParser(leaf)
          : null,
      null, // IndentedCode
      null, // FencedCode
      null, // Blockquote
      null, // HorizontalRule
      null, // BulletList
      null, // OrderedList
      null, // ATXHeading
      null, // HTMLBlock
      // SetextHeading
      (cx, leaf) => _SetextHeadingParser(),
    ],
    endLeafBlock: _defaultEndLeaf,
    skipContextMarkup: {
      MdNodeType.document.id: _skipDocument,
      MdNodeType.blockquote.id: _skipBlockquote,
      MdNodeType.listItem.id: _skipListItem,
      MdNodeType.bulletList.id: _skipForList,
      MdNodeType.orderedList.id: _skipForList,
    },
    inlineParsers: defaultInlineParsers(),
  );
}
