/// Types of block-level decorations that can be rendered in WYSIWYG mode.
enum MdBlockDecorationType {
  /// Fenced or indented code block region.
  codeBlock,

  /// Horizontal rule line.
  horizontalRule,

  /// Unordered list bullet marker (-, *, +).
  listBullet,

  /// Unchecked task list marker (- [ ]).
  taskUnchecked,

  /// Checked task list marker (- [x]).
  taskChecked,
}

/// Describes a block-level decoration to be rendered by the block painter.
class MdBlockDecoration {
  /// The type of decoration.
  final MdBlockDecorationType type;

  /// The first line of the decoration (0-based, inclusive).
  final int startLine;

  /// The last line of the decoration (0-based, inclusive).
  final int endLine;

  /// Column offset of the marker character within the line.
  /// Used for list bullet and task marker positioning.
  final int? markerColumn;

  /// Length of the marker text to hide (e.g. 2 for `- `, 6 for `- [x] `).
  final int? markerLength;

  const MdBlockDecoration({
    required this.type,
    required this.startLine,
    required this.endLine,
    this.markerColumn,
    this.markerLength,
  });
}

/// Types of Markdown lines for height calculation.
enum MdLineType {
  normal,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  codeBlock,
  horizontalRule,
  list,
}

/// Per-line metadata used for variable line height and block decorations.
class MdLineMetadata {
  /// The type of content on this line.
  final MdLineType type;

  /// Height scale factor relative to the base line height.
  /// 1.0 for normal lines, > 1.0 for headings.
  final double heightScale;

  const MdLineMetadata({
    required this.type,
    this.heightScale = 1.0,
  });

  static const normal = MdLineMetadata(type: MdLineType.normal);
}
