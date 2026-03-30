import 'md_element.dart';
import 'md_line.dart';
import 'md_node_type.dart';

bool _isSpace(int ch) => ch == 32 || ch == 9 || ch == 10 || ch == 13;

/// Punctuation regex matching Lezer's definition
final RegExp _punctuation = (() {
  try {
    // Try Unicode-aware pattern first
    return RegExp(r'[\p{S}|\p{P}]', unicode: true);
  } catch (_) {
    return RegExp(r'''[!"#$%&'()*+,\-.\/:;<=>?@\[\\\]^_`{|}~\xA1]''');
  }
})();

/// Characters that can be escaped with backslash
const String _escapable = r'!"#$%&' "'" r'()*+,-./:;<=>?@[\]^_`{|}~';

// ===================== Delimiter Types =====================

const _emphasisUnderscore = MdDelimiterType(
  resolve: MdNodeType.emphasis,
  mark: MdNodeType.emphasisMark,
);

const _emphasisAsterisk = MdDelimiterType(
  resolve: MdNodeType.emphasis,
  mark: MdNodeType.emphasisMark,
);

final _linkStart = MdDelimiterType();
final _imageStart = MdDelimiterType();

// ===================== InlineContext Implementation =====================

/// Inline parsing context, mirroring @lezer/markdown's InlineContext.
///
/// Processes inline formatting within block content by scanning
/// character by character, collecting delimiters, and resolving them
/// into syntax elements at the end.
class MdInlineContextImpl implements MdInlineContext {
  @override
  final MdMarkdownParser parser;

  @override
  final String text;

  @override
  final int offset;

  /// Collected parts: Element or InlineDelimiter or null (cleared)
  final List<Object?> parts = [];

  MdInlineContextImpl(this.parser, this.text, this.offset);

  @override
  int get end => offset + text.length;

  @override
  int char(int pos) => pos >= end ? -1 : text.codeUnitAt(pos - offset);

  @override
  String slice(int from, int to) {
    final f = (from - offset).clamp(0, text.length);
    final t = (to - offset).clamp(0, text.length);
    return text.substring(f, t);
  }

  @override
  int addElement(MdElement elt) => append(elt);

  @override
  int append(Object elt) {
    parts.add(elt);
    if (elt is MdElement) return elt.to;
    if (elt is MdInlineDelimiter) return elt.to;
    return -1;
  }

  @override
  int addDelimiter(
      MdDelimiterType type, int from, int to, bool open, bool close) {
    return append(MdInlineDelimiter(
      type,
      from,
      to,
      (open ? MdMark.open : MdMark.none) | (close ? MdMark.close : MdMark.none),
    ));
  }

  @override
  bool get hasOpenLink {
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (part is MdInlineDelimiter &&
          (identical(part.type, _linkStart) ||
              identical(part.type, _imageStart))) {
        return true;
      }
    }
    return false;
  }

  @override
  int? findOpeningDelimiter(MdDelimiterType type) {
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (part is MdInlineDelimiter && identical(part.type, type)) return i;
    }
    return null;
  }

  @override
  List<MdElement> takeContent(int startIndex) {
    final content = resolveMarkers(startIndex);
    parts.length = startIndex;
    return content;
  }

  @override
  int skipSpace(int from) {
    return skipSpaceGlobal(text, from - offset) + offset;
  }

  @override
  MdElement elt(MdNodeType type, int from, int to,
      [List<MdElement>? children]) {
    return MdElement(type, from, to, children);
  }

  @override
  List<MdElement> resolveMarkers(int from) {
    // Scan forward, looking for closing delimiters
    for (int i = from; i < parts.length; i++) {
      final close = parts[i];
      if (close is! MdInlineDelimiter ||
          close.type.resolve == null ||
          (close.side & MdMark.close) == 0) {
        continue;
      }

      final bool isEmphasis = identical(close.type, _emphasisUnderscore) ||
          identical(close.type, _emphasisAsterisk);
      int closeSize = close.to - close.from;

      MdInlineDelimiter? open;
      int j = i - 1;

      // Scan backward for matching opener
      for (; j >= from; j--) {
        final part = parts[j];
        if (part is MdInlineDelimiter &&
            (part.side & MdMark.open) != 0 &&
            identical(part.type, close.type)) {
          // CommonMark emphasis rule: if both can open & close, sum % 3 check
          if (isEmphasis &&
              ((close.side & MdMark.open) != 0 ||
                  (part.side & MdMark.close) != 0) &&
              (part.to - part.from + closeSize) % 3 == 0 &&
              ((part.to - part.from) % 3 != 0 || closeSize % 3 != 0)) {
            continue; // Skip this pair per the 3-char rule
          }
          open = part;
          break;
        }
      }

      if (open == null) continue;

      final resolveType = close.type.resolve!;
      final content = <MdElement>[];
      int start = open.from, end = close.to;

      // Emphasis: consume min(2, available) chars from each side
      MdNodeType nodeType = resolveType;
      if (isEmphasis) {
        final size = _min3(2, open.to - open.from, closeSize);
        start = open.to - size;
        end = close.from + size;
        nodeType = size == 1 ? MdNodeType.emphasis : MdNodeType.strongEmphasis;
      }

      // Collect marks and inner content
      if (open.type.mark != null) {
        content.add(MdElement(open.type.mark!, start, open.to));
      }
      for (int k = j + 1; k < i; k++) {
        if (parts[k] is MdElement) content.add(parts[k] as MdElement);
        parts[k] = null;
      }
      if (close.type.mark != null) {
        content.add(MdElement(close.type.mark!, close.from, end));
      }

      final element = MdElement(nodeType, start, end, content);

      // Handle leftover delimiter characters
      if (isEmphasis && open.from != start) {
        parts[j] = MdInlineDelimiter(open.type, open.from, start, open.side);
      } else {
        parts[j] = null;
      }

      final bool hasLeftover = isEmphasis && close.to != end;
      if (hasLeftover) {
        final keep = MdInlineDelimiter(close.type, end, close.to, close.side);
        parts[i] = keep;
        parts.insert(i, element);
      } else {
        parts[i] = element;
      }
    }

    // Collect remaining elements
    final result = <MdElement>[];
    for (int i = from; i < parts.length; i++) {
      final part = parts[i];
      if (part is MdElement) result.add(part);
    }
    return result;
  }
}

int _min3(int a, int b, int c) {
  if (a <= b && a <= c) return a;
  return b <= c ? b : c;
}

// ===================== Default Inline Parsers =====================

/// Escape: \X where X is an ASCII punctuation character
int parseEscape(MdInlineContext cx, int next, int start) {
  if (next != 0x5C /* '\\' */ || start == cx.end - 1) return -1;
  final escaped = cx.char(start + 1);
  for (int i = 0; i < _escapable.length; i++) {
    if (_escapable.codeUnitAt(i) == escaped) {
      return cx.addElement(MdElement(MdNodeType.escape, start, start + 2));
    }
  }
  return -1;
}

/// HTML entity: &#123; &#x1F; &amp;
int parseEntity(MdInlineContext cx, int next, int start) {
  if (next != 0x26 /* '&' */) return -1;
  final rest = cx.slice(start + 1, (start + 31).clamp(0, cx.end));
  final m = RegExp(r'^(?:#\d+|#x[a-fA-F\d]+|\w+);').firstMatch(rest);
  if (m == null) return -1;
  return cx.addElement(
      MdElement(MdNodeType.entity, start, start + 1 + m.group(0)!.length));
}

/// Inline code: `code` or ``code with ` backtick``
int parseInlineCode(MdInlineContext cx, int next, int start) {
  if (next != 0x60 /* '`' */) return -1;
  // Don't match if preceded by backtick
  if (start > cx.offset && cx.char(start - 1) == 0x60) return -1;

  int pos = start + 1;
  while (pos < cx.end && cx.char(pos) == 0x60) pos++;
  final size = pos - start;
  int curSize = 0;

  for (; pos < cx.end; pos++) {
    if (cx.char(pos) == 0x60) {
      curSize++;
      if (curSize == size && cx.char(pos + 1) != 0x60) {
        return cx.addElement(MdElement(
          MdNodeType.inlineCode,
          start,
          pos + 1,
          [
            MdElement(MdNodeType.codeMark, start, start + size),
            MdElement(MdNodeType.codeMark, pos + 1 - size, pos + 1),
          ],
        ));
      }
    } else {
      curSize = 0;
    }
  }
  return -1;
}

/// HTML tag, autolink (<url>), or comment inline
int parseHTMLTag(MdInlineContext cx, int next, int start) {
  if (next != 0x3C /* '<' */ || start == cx.end - 1) return -1;
  final after = cx.slice(start + 1, cx.end);

  // Autolink: <http://...> or <email@addr>
  final url = RegExp(
    r'^(?:[a-zA-Z][-\w+.]+:[^\s>]+|[a-zA-Z\d.!#$%&'
    "'"
    r'*+/=?^_`{|}~-]+@[a-zA-Z\d](?:[a-zA-Z\d-]{0,61}[a-zA-Z\d])?(?:\.[a-zA-Z\d](?:[a-zA-Z\d-]{0,61}[a-zA-Z\d])?)*)>',
  ).firstMatch(after);
  if (url != null) {
    return cx.addElement(MdElement(
      MdNodeType.autolink,
      start,
      start + 1 + url.group(0)!.length,
      [
        MdElement(MdNodeType.linkMark, start, start + 1),
        MdElement(MdNodeType.url, start + 1, start + url.group(0)!.length),
        MdElement(MdNodeType.linkMark, start + url.group(0)!.length,
            start + 1 + url.group(0)!.length),
      ],
    ));
  }

  // Comment: <!-- ... -->
  final comment = RegExp(r'^!--[^>](?:-[^-]|[^-])*?-->').firstMatch(after);
  if (comment != null) {
    return cx.addElement(MdElement(
        MdNodeType.comment, start, start + 1 + comment.group(0)!.length));
  }

  // Processing instruction: <? ... ?>
  final procInst = RegExp(r'^\?[\s\S]*?\?>').firstMatch(after);
  if (procInst != null) {
    return cx.addElement(MdElement(MdNodeType.processingInstruction, start,
        start + 1 + procInst.group(0)!.length));
  }

  // HTML tag
  final m = RegExp(
    r'^(?:![A-Z][\s\S]*?>|!\[CDATA\[[\s\S]*?\]\]>|\/\s*[a-zA-Z][\w-]*\s*>|\s*[a-zA-Z][\w-]*(\s+[a-zA-Z:_][\w-.:]*(?:\s*=\s*(?:[^\s"'
    "'"
    r'=<>`]+|'
    "'"
    r"[^']*'"
    r'|"[^"]*"))?)*\s*(\/\s*)?>)',
  ).firstMatch(after);
  if (m == null) return -1;
  return cx.addElement(
      MdElement(MdNodeType.htmlTag, start, start + 1 + m.group(0)!.length));
}

/// Emphasis: * and _ delimiters with CommonMark flanking rules
int parseEmphasis(MdInlineContext cx, int next, int start) {
  if (next != 0x5F /* '_' */ && next != 0x2A /* '*' */) return -1;

  int pos = start + 1;
  while (pos < cx.end && cx.char(pos) == next) pos++;

  final before = cx.slice(start - 1, start);
  final after = cx.slice(pos, pos + 1);

  final pBefore = _punctuation.hasMatch(before);
  final pAfter = _punctuation.hasMatch(after);
  final sBefore = before.isEmpty || RegExp(r'\s').hasMatch(before);
  final sAfter = after.isEmpty || RegExp(r'\s').hasMatch(after);

  final leftFlanking = !sAfter && (!pAfter || sBefore || pBefore);
  final rightFlanking = !sBefore && (!pBefore || sAfter || pAfter);

  final canOpen = leftFlanking && (next == 0x2A || !rightFlanking || pBefore);
  final canClose = rightFlanking && (next == 0x2A || !leftFlanking || pAfter);

  return cx.addDelimiter(
    next == 0x5F ? _emphasisUnderscore : _emphasisAsterisk,
    start,
    pos,
    canOpen,
    canClose,
  );
}

/// Hard break: \\ at end of line, or 2+ spaces before newline
int parseHardBreak(MdInlineContext cx, int next, int start) {
  if (next == 0x5C /* '\\' */ && cx.char(start + 1) == 0x0A /* '\n' */) {
    return cx.addElement(MdElement(MdNodeType.hardBreak, start, start + 2));
  }
  if (next == 0x20 /* ' ' */) {
    int pos = start + 1;
    while (cx.char(pos) == 0x20) pos++;
    if (cx.char(pos) == 0x0A && pos >= start + 2) {
      return cx.addElement(MdElement(MdNodeType.hardBreak, start, pos + 1));
    }
  }
  return -1;
}

/// Link opening: [
int parseLink(MdInlineContext cx, int next, int start) {
  return next == 0x5B /* '[' */
      ? cx.append(MdInlineDelimiter(_linkStart, start, start + 1, MdMark.open))
      : -1;
}

/// Image opening: ![
int parseImage(MdInlineContext cx, int next, int start) {
  return next == 0x21 /* '!' */ && cx.char(start + 1) == 0x5B /* '[' */
      ? cx.append(MdInlineDelimiter(_imageStart, start, start + 2, MdMark.open))
      : -1;
}

/// Link/Image closing: ]
int parseLinkEnd(MdInlineContext cx, int next, int start) {
  if (next != 0x5D /* ']' */) return -1;
  final cxi = cx as MdInlineContextImpl;

  // Scan backward for opening [ or ![
  for (int i = cxi.parts.length - 1; i >= 0; i--) {
    final part = cxi.parts[i];
    if (part is MdInlineDelimiter &&
        (identical(part.type, _linkStart) ||
            identical(part.type, _imageStart))) {
      // Check if marked invalid, or empty link with no following (
      if (part.side == MdMark.none ||
          (cx.skipSpace(part.to) == start &&
              !RegExp(r'[(\[]').hasMatch(cx.slice(start + 1, start + 2)))) {
        cxi.parts[i] = null;
        return -1;
      }

      final content = cx.takeContent(i);
      final link = _finishLink(
        cx,
        content,
        identical(part.type, _linkStart) ? MdNodeType.link : MdNodeType.image,
        part.from,
        start + 1,
      );
      cxi.parts.add(link);

      // Invalidate any earlier link openers (no nested links)
      if (identical(part.type, _linkStart)) {
        for (int j = 0; j < cxi.parts.length - 1; j++) {
          final p = cxi.parts[j];
          if (p is MdInlineDelimiter && identical(p.type, _linkStart)) {
            p.side = MdMark.none;
          }
        }
      }
      return link.to;
    }
  }
  return -1;
}

MdElement _finishLink(MdInlineContext cx, List<MdElement> content,
    MdNodeType type, int start, int startPos) {
  final next = cx.char(startPos);
  int endPos = startPos;

  // Add marks for [ and ]
  content.insert(
    0,
    MdElement(
        MdNodeType.linkMark, start, start + (type == MdNodeType.image ? 2 : 1)),
  );
  content.add(MdElement(MdNodeType.linkMark, startPos - 1, startPos));

  if (next == 0x28 /* '(' */) {
    // Inline link: [text](url "title")
    int pos = cx.skipSpace(startPos + 1);
    final dest = _parseURL(cx.text, pos - cx.offset, cx.offset);
    MdElement? title;
    if (dest != null) {
      pos = cx.skipSpace(dest.to);
      if (pos != dest.to) {
        title = _parseLinkTitle(cx.text, pos - cx.offset, cx.offset);
        if (title != null) pos = cx.skipSpace(title.to);
      }
    }
    if (cx.char(pos) == 0x29 /* ')' */) {
      content.add(MdElement(MdNodeType.linkMark, startPos, startPos + 1));
      endPos = pos + 1;
      if (dest != null) content.add(dest);
      if (title != null) content.add(title);
      content.add(MdElement(MdNodeType.linkMark, pos, endPos));
    }
  } else if (next == 0x5B /* '[' */) {
    // Reference link: [text][label]
    final label =
        _parseLinkLabel(cx.text, startPos - cx.offset, cx.offset, false);
    if (label != null) {
      content.add(label);
      endPos = label.to;
    }
  }

  return MdElement(type, start, endPos, content);
}

/// Parse a URL in link syntax. Returns null if not found.
MdElement? _parseURL(String text, int start, int offset) {
  if (start >= text.length) return null;
  final next = text.codeUnitAt(start);
  if (next == 0x3C /* '<' */) {
    for (int pos = start + 1; pos < text.length; pos++) {
      final ch = text.codeUnitAt(pos);
      if (ch == 0x3E /* '>' */) {
        return MdElement(MdNodeType.url, start + offset, pos + 1 + offset);
      }
      if (ch == 0x3C || ch == 0x0A) return null;
    }
    return null;
  } else {
    int depth = 0;
    int pos = start;
    bool escaped = false;
    for (; pos < text.length; pos++) {
      final ch = text.codeUnitAt(pos);
      if (_isSpace(ch)) break;
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == 0x28 /* '(' */) {
        depth++;
      } else if (ch == 0x29 /* ')' */) {
        if (depth == 0) break;
        depth--;
      } else if (ch == 0x5C /* '\\' */) {
        escaped = true;
      }
    }
    return pos > start
        ? MdElement(MdNodeType.url, start + offset, pos + offset)
        : null;
  }
}

/// Parse a link title ("title" or 'title' or (title))
MdElement? _parseLinkTitle(String text, int start, int offset) {
  if (start >= text.length) return null;
  final next = text.codeUnitAt(start);
  if (next != 0x27 /* "'" */ &&
      next != 0x22 /* '"' */ &&
      next != 0x28 /* '(' */) return null;
  final end = next == 0x28 ? 0x29 : next;
  for (int pos = start + 1; pos < text.length; pos++) {
    final ch = text.codeUnitAt(pos);
    if (ch == 0x5C /* '\\' */) {
      pos++; // skip escaped char
      continue;
    }
    if (ch == end) {
      return MdElement(MdNodeType.linkTitle, start + offset, pos + 1 + offset);
    }
  }
  return null;
}

/// Parse a link label [label], returns null if not found
MdElement? _parseLinkLabel(
    String text, int start, int offset, bool requireNonWS) {
  bool escaped = false;
  for (int pos = start + 1; pos < text.length && pos < start + 1000; pos++) {
    final ch = text.codeUnitAt(pos);
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch == 0x5D /* ']' */) {
      return requireNonWS
          ? null
          : MdElement(MdNodeType.linkLabel, start + offset, pos + 1 + offset);
    }
    if (requireNonWS && !_isSpace(ch)) requireNonWS = false;
    if (ch == 0x5B /* '[' */) return null;
    if (ch == 0x5C /* '\\' */) escaped = true;
  }
  return null;
}

/// Default inline parsers in order, matching Lezer's DefaultInline
List<MdInlineParserFn> defaultInlineParsers() {
  return [
    parseEscape,
    parseEntity,
    parseInlineCode,
    parseHTMLTag,
    parseEmphasis,
    parseHardBreak,
    parseLink,
    parseImage,
    parseLinkEnd,
  ];
}
