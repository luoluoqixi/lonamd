import 'md_element.dart';
import 'md_node_type.dart';

/// Per-line parsing state, mirroring @lezer/markdown's Line class.
///
/// As composite blocks (blockquotes, lists) consume their markup from
/// the beginning of a line, this tracks how far we've progressed.
class MdLine {
  /// The full line text
  String text = '';

  /// The indent provided by composite block contexts handled so far
  int baseIndent = 0;

  /// The string position corresponding to [baseIndent]
  int basePos = 0;

  /// Number of composite contexts handled
  int depth = 0;

  /// Markup elements collected for composite blocks (quote marks, etc.)
  List<MdElement> markers = [];

  /// Position of next non-whitespace character after contexts
  int pos = 0;

  /// Column of next non-whitespace character
  int indent = 0;

  /// Character code at [pos], or -1 if at end
  int next = -1;

  /// Reset for a new line
  void reset(String text) {
    this.text = text;
    baseIndent = 0;
    basePos = 0;
    pos = 0;
    indent = 0;
    depth = 1;
    markers.clear();
    _forwardInner();
  }

  /// Update pos/indent after context markup skip
  void forward() {
    if (basePos > pos) _forwardInner();
  }

  void _forwardInner() {
    final newPos = skipSpace(text, basePos);
    indent = countIndent(newPos, pos, indent);
    pos = newPos;
    next = newPos == text.length ? -1 : text.codeUnitAt(newPos);
  }

  /// Move the base position forward
  void moveBase(int to) {
    basePos = to;
    baseIndent = countIndent(to, pos, indent);
  }

  /// Move the base position forward to a given column
  void moveBaseColumn(int indent) {
    baseIndent = indent;
    basePos = findColumn(indent);
  }

  /// Store a composite-block marker element
  void addMarker(MdElement elt) {
    markers.add(elt);
  }

  /// Count the column position at [to], starting from [from] at column [indent]
  int countIndent(int to, [int from = 0, int indent = 0]) {
    for (int i = from; i < to; i++) {
      indent += text.codeUnitAt(i) == 9 ? 4 - indent % 4 : 1; // tab = 4
    }
    return indent;
  }

  /// Find the string position corresponding to a given column
  int findColumn(int goal) {
    int i = 0;
    for (int indent = 0; i < text.length && indent < goal; i++) {
      indent += text.codeUnitAt(i) == 9 ? 4 - indent % 4 : 1;
    }
    return i;
  }

  /// Skip whitespace from [from], return position of first non-space or end
  int skipSpace(String line, [int i = 0]) {
    while (i < line.length && _isSpace(line.codeUnitAt(i))) i++;
    return i;
  }

  /// Get the "scrubbed" line content: spaces replacing composite block markup
  String scrub() {
    if (basePos == 0) return text;
    final result = StringBuffer();
    for (int i = 0; i < basePos; i++) {
      result.write(' ');
    }
    result.write(text.substring(basePos));
    return result.toString();
  }
}

/// Data accumulated for a leaf block during parsing.
///
/// Leaf blocks are paragraph-like constructs. They accumulate lines
/// until a blank line, block-level break, or a LeafBlockParser decides
/// to handle them (e.g., setext heading, link reference).
class MdLeafBlock {
  /// The start position
  final int start;

  /// Accumulated text content
  String content;

  /// Composite block markers collected during accumulation
  List<MdElement> marks = [];

  /// Custom leaf block parsers active for this leaf
  List<MdLeafBlockParser> parsers = [];

  MdLeafBlock(this.start, this.content);
}

/// Interface for leaf block parsers that observe a paragraph-like block
/// and optionally decide to handle it.
abstract class MdLeafBlockParser {
  /// Called for each subsequent line after the first.
  /// Return true to indicate the block is finished.
  bool nextLine(MdBlockContext cx, MdLine line, MdLeafBlock leaf);

  /// Called when the leaf is terminated by external circumstances.
  /// Return true if this parser handled the block.
  bool finish(MdBlockContext cx, MdLeafBlock leaf);
}

/// A composite (container) block during parsing.
///
/// Tracks nested structure like blockquotes and lists.
class MdCompositeBlock {
  final MdNodeType type;

  /// Used for indentation in list items, markup character in lists
  final int value;

  /// Start position in document
  final int from;

  /// Context hash for incremental parsing
  final int hash;

  /// Current end position (grows until finalized)
  int end;

  /// Child elements collected during parsing
  final List<MdElement> children = [];

  /// Relative positions of children
  final List<int> positions = [];

  MdCompositeBlock(this.type, this.value, this.from, this.hash, this.end);

  factory MdCompositeBlock.create(
    MdNodeType type,
    int value,
    int from,
    int parentHash,
    int end,
  ) {
    // Hash function matching Lezer's
    final hash =
        (parentHash + (parentHash << 8) + type.id + (value << 4)) & 0x7FFFFFFF;
    return MdCompositeBlock(type, value, from, hash, end);
  }

  void addChild(MdElement child, int pos) {
    children.add(child);
    positions.add(pos);
  }

  /// Build the final element for this composite block
  MdElement toElement([int? endPos]) {
    final e = endPos ?? end;
    return MdElement(type, from, e, List.of(children));
  }
}

/// Result type for block parsing functions.
///
/// - `false` → parser didn't match, try next parser
/// - `true`  → leaf block was parsed and stream advanced
/// - `null`  → a composite context was opened, continue on this line
enum MdBlockResult { none, leaf, context }

/// Type for block parser functions
typedef MdBlockParserFn = MdBlockResult Function(
    MdBlockContext cx, MdLine line);

/// Type for leaf block parser factory functions
typedef MdLeafBlockParserFn = MdLeafBlockParser? Function(
    MdBlockContext cx, MdLeafBlock leaf);

/// Type for composite block skip-markup functions.
/// Returns true if the composite block continues on this line.
typedef MdSkipMarkupFn = bool Function(
    MdCompositeBlock bl, MdBlockContext cx, MdLine line);

/// Type for leaf-ending predicate functions
typedef MdEndLeafFn = bool Function(
    MdBlockContext cx, MdLine line, MdLeafBlock leaf);

/// Type for inline parser functions.
/// Returns -1 if not handled, or end position if handled.
typedef MdInlineParserFn = int Function(MdInlineContext cx, int next, int pos);

// ===================== Utility Functions =====================

bool _isSpace(int ch) => ch == 32 || ch == 9 || ch == 10 || ch == 13;

int skipSpaceGlobal(String line, [int i = 0]) {
  while (i < line.length && _isSpace(line.codeUnitAt(i))) i++;
  return i;
}

int skipSpaceBack(String line, int i, int to) {
  while (i > to && _isSpace(line.codeUnitAt(i - 1))) i--;
  return i;
}

// Forward declaration — actual implementations are in md_block_context.dart
// and md_inline_context.dart. This file only defines the data structures.

/// The block-level parsing context. See md_block_context.dart for implementation.
abstract class MdBlockContext {
  MdLine get line;
  int get lineStart;
  MdCompositeBlock get block;
  List<MdCompositeBlock> get stack;
  MdMarkdownParser get parser;

  bool nextLine();
  String peekLine();
  void addNode(MdNodeType type, int from, [int? to]);
  void addElement(MdElement elt);
  void addLeafElement(MdLeafBlock leaf, MdElement elt);
  void startContext(MdNodeType type, int start, [int value = 0]);
  void finishContext();
  int prevLineEnd();
}

/// The inline parsing context. See md_inline_context.dart for implementation.
abstract class MdInlineContext {
  MdMarkdownParser get parser;
  String get text;
  int get offset;
  int get end;

  int char(int pos);
  String slice(int from, int to);
  int addElement(MdElement elt);
  int append(Object elt); // Element or InlineDelimiter
  int addDelimiter(
      MdDelimiterType type, int from, int to, bool open, bool close);
  int? findOpeningDelimiter(MdDelimiterType type);
  List<MdElement> takeContent(int startIndex);
  List<MdElement> resolveMarkers(int from);
  bool get hasOpenLink;
  int skipSpace(int from);
  MdElement elt(MdNodeType type, int from, int to, [List<MdElement>? children]);
}

/// The parser configuration. Forward declaration.
abstract class MdMarkdownParser {
  List<MdBlockParserFn?> get blockParsers;
  List<MdLeafBlockParserFn?> get leafBlockParsers;
  List<MdEndLeafFn> get endLeafBlock;
  Map<int, MdSkipMarkupFn> get skipContextMarkup;
  List<MdInlineParserFn?> get inlineParsers;
  List<MdElement> parseInline(String text, int offset);
}
