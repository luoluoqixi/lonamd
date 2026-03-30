import 'md_node_type.dart';

/// A syntax element in the Markdown AST.
///
/// Mirrors @lezer/markdown's Element class. Each element has a type,
/// a range [from, to) in the source document, and optional children.
class MdElement {
  /// The node type
  final MdNodeType type;

  /// Start position (document-relative, inclusive)
  final int from;

  /// End position (document-relative, exclusive)
  int to;

  /// Child elements
  final List<MdElement> children;

  MdElement(this.type, this.from, this.to, [List<MdElement>? children])
      : children = children ?? const [];

  /// The length of this element's range
  int get length => to - from;

  @override
  String toString() {
    if (children.isEmpty) {
      return '${type.name}($from, $to)';
    }
    return '${type.name}($from, $to, $children)';
  }
}

/// An inline delimiter used during inline parsing.
///
/// Delimiters track potential opening/closing markers (like * or ~)
/// that need to be matched retroactively after scanning the full inline text.
class MdInlineDelimiter {
  /// The delimiter type (defines how to resolve matches)
  final MdDelimiterType type;

  /// Start position in document
  final int from;

  /// End position in document
  final int to;

  /// Whether this delimiter can open and/or close
  int side;

  MdInlineDelimiter(this.type, this.from, this.to, this.side);

  /// Number of delimiter characters
  int get size => to - from;
}

/// Defines how an inline delimiter should be resolved when matched.
class MdDelimiterType {
  /// Node type name to create when a matching pair is found.
  /// If null, manual resolution via [findOpeningDelimiter] is needed.
  final MdNodeType? resolve;

  /// Mark node type to wrap the delimiter characters themselves
  final MdNodeType? mark;

  const MdDelimiterType({this.resolve, this.mark});
}

/// Side flags for inline delimiters
class MdMark {
  static const int none = 0;
  static const int open = 1;
  static const int close = 2;
}
