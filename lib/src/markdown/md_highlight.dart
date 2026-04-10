import 'package:lonamd/highlight.dart';

import 'md_block_context.dart';
import 'md_element.dart';
import 'md_extension.dart';
import 'md_node_type.dart';

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
    case MdNodeType.atxHeading2:
    case MdNodeType.atxHeading3:
    case MdNodeType.atxHeading4:
    case MdNodeType.atxHeading5:
    case MdNodeType.atxHeading6:
    case MdNodeType.setextHeading1:
    case MdNodeType.setextHeading2:
      return 'section';
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
}
