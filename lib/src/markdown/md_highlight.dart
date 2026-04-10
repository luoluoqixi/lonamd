import 'package:lonamd/highlight.dart';

import 'md_block_context.dart';
import 'md_block_decoration.dart';
import 'md_element.dart';
import 'md_extension.dart';
import 'md_node_type.dart';
import 'md_wysiwyg_state.dart';

// ===================== MdNodeType → Scope Mapping =====================

/// Maps an [MdNodeType] to a Re-Highlight scope name for styling.
///
/// Returns `null` for structural nodes that should not receive a scope
/// (document, paragraph, list containers, etc.), allowing their children
/// to be styled individually.
String? _scopeForType(MdNodeType type) {
  switch (type) {
    // Block nodes — structural, no scope
    case MdNodeType.document:
    case MdNodeType.paragraph:
    case MdNodeType.bulletList:
    case MdNodeType.orderedList:
    case MdNodeType.listItem:
      return null;

    // Block nodes — styled
    case MdNodeType.codeBlock:
    case MdNodeType.fencedCode:
      return 'code';
    case MdNodeType.blockquote:
      return 'quote';
    case MdNodeType.horizontalRule:
      return 'md-mark';
    case MdNodeType.atxHeading1:
    case MdNodeType.setextHeading1:
      return 'section-h1';
    case MdNodeType.atxHeading2:
    case MdNodeType.setextHeading2:
      return 'section-h2';
    case MdNodeType.atxHeading3:
      return 'section-h3';
    case MdNodeType.atxHeading4:
      return 'section-h4';
    case MdNodeType.atxHeading5:
      return 'section-h5';
    case MdNodeType.atxHeading6:
      return 'section-h6';
    case MdNodeType.htmlBlock:
      return 'meta';
    case MdNodeType.linkReference:
      return 'symbol';
    case MdNodeType.commentBlock:
      return 'comment';
    case MdNodeType.processingInstructionBlock:
      return 'meta';

    // Inline nodes
    case MdNodeType.escape:
      return 'meta';
    case MdNodeType.entity:
      return 'meta';
    case MdNodeType.hardBreak:
      return null;
    case MdNodeType.emphasis:
      return 'emphasis';
    case MdNodeType.strongEmphasis:
      return 'strong';
    case MdNodeType.link:
      return 'link';
    case MdNodeType.image:
      return 'link';
    case MdNodeType.inlineCode:
      return 'code';
    case MdNodeType.htmlTag:
      return 'meta';
    case MdNodeType.comment:
      return 'comment';
    case MdNodeType.processingInstruction:
      return 'meta';
    case MdNodeType.autolink:
      return 'link';

    // Mark/token nodes
    case MdNodeType.headerMark:
      return 'md-mark';
    case MdNodeType.quoteMark:
      return 'md-mark';
    case MdNodeType.listMark:
      return 'bullet';
    case MdNodeType.linkMark:
      return 'md-mark';
    case MdNodeType.emphasisMark:
      return 'md-mark';
    case MdNodeType.codeMark:
      return 'md-mark';
    case MdNodeType.codeText:
      return 'code';
    case MdNodeType.codeInfo:
      return 'string';
    case MdNodeType.linkTitle:
      return 'string';
    case MdNodeType.linkLabel:
      return 'symbol';
    case MdNodeType.url:
      return 'link';

    // GFM extension nodes
    case MdNodeType.strikethrough:
      return 'deletion';
    case MdNodeType.strikethroughMark:
      return 'md-mark';
    case MdNodeType.table:
      return null;
    case MdNodeType.tableHeader:
      return 'section';
    case MdNodeType.tableRow:
      return null;
    case MdNodeType.tableCell:
      return null;
    case MdNodeType.tableDelimiter:
      return 'meta';
    case MdNodeType.task:
      return null;
    case MdNodeType.taskMarker:
      return 'bullet';
    case MdNodeType.highlight:
      return 'addition';
    case MdNodeType.highlightMark:
      return 'md-mark';
  }
}

// ===================== AST → Token Tree Emitter =====================

/// Walk the AST and emit scoped tokens for Re-Highlight.
///
/// This flattens the tree into a linear sequence of addText/startScope/endScope
/// calls, which is the same format Re-Highlight produces from its regex engine.
void _emitNode(MdElement node, String text, Emitter emitter) {
  final scope = _scopeForType(node.type);
  if (scope != null) {
    emitter.startScope(scope);
  }

  if (node.children.isEmpty) {
    // Leaf node — emit its text range
    final from = node.from.clamp(0, text.length);
    final to = node.to.clamp(from, text.length);
    if (to > from) {
      emitter.addText(text.substring(from, to));
    }
  } else {
    // Node with children — emit gaps between children
    int pos = node.from.clamp(0, text.length);
    for (final child in node.children) {
      final childFrom = child.from.clamp(pos, text.length);
      if (childFrom > pos) {
        emitter.addText(text.substring(pos, childFrom));
      }
      _emitNode(child, text, emitter);
      pos = child.to.clamp(childFrom, text.length);
    }
    final nodeTo = node.to.clamp(pos, text.length);
    if (nodeTo > pos) {
      emitter.addText(text.substring(pos, nodeTo));
    }
  }

  if (scope != null) {
    emitter.endScope();
  }
}

// ===================== Highlight Plugin =====================

/// An [HLPlugin] that replaces Re-Highlight's regex-based Markdown
/// highlighting with our AST-based Markdown parser.
///
/// When the language is "markdown" (or its aliases), this plugin
/// intercepts the highlight call, parses the document with
/// [gfmMarkdownParser], and builds a [HighlightResult] from the AST.
///
/// Usage:
/// ```dart
/// final theme = CodeHighlightTheme(
///   languages: {'markdown': langMarkdown.themeMode},
///   theme: myThemeMap,
///   plugins: [MdHighlightPlugin()],
/// );
/// ```
class MdHighlightPlugin extends HLPlugin {
  final MdMarkdownParserImpl _parser;

  /// Optional WYSIWYG state to populate with line metadata and
  /// block decorations during AST processing.
  MdWysiwygState? wysiwygState;

  /// Create the plugin. Optionally provide a custom parser;
  /// defaults to [gfmMarkdownParser].
  MdHighlightPlugin([MdMarkdownParserImpl? parser])
      : _parser = parser ?? gfmMarkdownParser();

  static const _markdownNames = {'markdown', 'md', 'mkdown', 'mkd'};

  @override
  void beforeHighlight(BeforeHighlightContext context) {
    if (!_markdownNames.contains(context.language.toLowerCase())) return;

    final code = context.code;
    final doc = _parser.parseDocument(code);

    context.result = HighlightResult.build(code, (emitter) {
      _emitNode(doc, code, emitter);
    });
    context.result!.language = context.language;
  }

  @override
  void afterHighlight(HighlightResult result) {
    // No post-processing needed
  }

  /// Populate [state] with line metadata and block decorations by parsing
  /// [code] on the main thread. Call this from [_CodeHighlighter] instead
  /// of inside [beforeHighlight] which runs in an isolate.
  void populateMetadata(String code, MdWysiwygState state) {
    final doc = _parser.parseDocument(code);
    _populateMetadata(doc, code, state);
  }
}

// ===================== AST → Metadata Extraction =====================

/// Heading scale factors for h1-h6 (default values).
const _defaultHeadingScales = [1.802, 1.502, 1.300, 1.150, 1.0, 1.0];

/// Populate WYSIWYG state with line metadata and block decorations
/// extracted from the AST.
void _populateMetadata(MdElement doc, String code, MdWysiwygState state) {
  final lineMetadata = <int, MdLineMetadata>{};
  final blockDecorations = <MdBlockDecoration>[];
  final lineStarts = _buildLineStarts(code);
  final scales = state.config.enableHeadingScale
      ? state.config.headingScales
      : _defaultHeadingScales;

  _extractMetadata(doc, code, lineStarts, lineMetadata, blockDecorations,
      scales, state.config);
  state.lineMetadata = lineMetadata;
  state.blockDecorations = blockDecorations;
}

/// Build a list of document offsets where each line starts.
/// lineStarts[i] = offset of the first character on line i.
List<int> _buildLineStarts(String code) {
  final starts = <int>[0];
  for (int i = 0; i < code.length; i++) {
    if (code.codeUnitAt(i) == 0x0A) {
      starts.add(i + 1);
    }
  }
  return starts;
}

/// Get the line number for a given document offset.
int _lineForOffset(List<int> lineStarts, int offset) {
  int lo = 0, hi = lineStarts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (lineStarts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// Recursively extract metadata from AST nodes.
void _extractMetadata(
  MdElement node,
  String code,
  List<int> lineStarts,
  Map<int, MdLineMetadata> lineMetadata,
  List<MdBlockDecoration> blockDecorations,
  List<double> headingScales,
  dynamic config,
) {
  switch (node.type) {
    case MdNodeType.atxHeading1:
    case MdNodeType.setextHeading1:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading1,
          headingScales[0]);
      break;
    case MdNodeType.atxHeading2:
    case MdNodeType.setextHeading2:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading2,
          headingScales[1]);
      break;
    case MdNodeType.atxHeading3:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading3,
          headingScales[2]);
      break;
    case MdNodeType.atxHeading4:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading4,
          headingScales[3]);
      break;
    case MdNodeType.atxHeading5:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading5,
          headingScales[4]);
      break;
    case MdNodeType.atxHeading6:
      _addHeadingMetadata(node, lineStarts, lineMetadata, MdLineType.heading6,
          headingScales[5]);
      break;
    case MdNodeType.fencedCode:
      final startLine = _lineForOffset(lineStarts, node.from);
      final endLine =
          _lineForOffset(lineStarts, (node.to - 1).clamp(0, code.length - 1));
      for (int i = startLine; i <= endLine; i++) {
        lineMetadata[i] = const MdLineMetadata(type: MdLineType.codeBlock);
      }
      blockDecorations.add(MdBlockDecoration(
        type: MdBlockDecorationType.codeBlock,
        startLine: startLine,
        endLine: endLine,
      ));
      break;
    case MdNodeType.horizontalRule:
      final line = _lineForOffset(lineStarts, node.from);
      lineMetadata[line] =
          const MdLineMetadata(type: MdLineType.horizontalRule);
      blockDecorations.add(MdBlockDecoration(
        type: MdBlockDecorationType.horizontalRule,
        startLine: line,
        endLine: line,
      ));
      break;
    case MdNodeType.listMark:
      final line = _lineForOffset(lineStarts, node.from);
      final col = node.from - lineStarts[line];
      final len = node.to - node.from;
      if (!lineMetadata.containsKey(line)) {
        lineMetadata[line] = const MdLineMetadata(type: MdLineType.list);
      }
      blockDecorations.add(MdBlockDecoration(
        type: MdBlockDecorationType.listBullet,
        startLine: line,
        endLine: line,
        markerColumn: col,
        markerLength: len,
      ));
      break;
    case MdNodeType.taskMarker:
      final line = _lineForOffset(lineStarts, node.from);
      final col = node.from - lineStarts[line];
      // Task marker includes the checkbox text like "[ ] " or "[x] "
      final len = node.to - node.from;
      final text =
          code.substring(node.from, node.to.clamp(node.from, code.length));
      final isChecked = text.contains('x') || text.contains('X');
      // Find the associated listMark to get the full range
      // The full task prefix is "- [ ] " which includes the listMark before the taskMarker
      blockDecorations.add(MdBlockDecoration(
        type: isChecked
            ? MdBlockDecorationType.taskChecked
            : MdBlockDecorationType.taskUnchecked,
        startLine: line,
        endLine: line,
        markerColumn: col,
        markerLength: len,
      ));
      break;
    default:
      break;
  }

  for (final child in node.children) {
    _extractMetadata(child, code, lineStarts, lineMetadata, blockDecorations,
        headingScales, config);
  }
}

void _addHeadingMetadata(
  MdElement node,
  List<int> lineStarts,
  Map<int, MdLineMetadata> lineMetadata,
  MdLineType type,
  double scale,
) {
  final line = _lineForOffset(lineStarts, node.from);
  lineMetadata[line] = MdLineMetadata(type: type, heightScale: scale);
}
