import 'package:flutter/painting.dart';

/// Configuration for WYSIWYG Markdown editing behavior.
///
/// Controls how Markdown formatting marks are displayed and which
/// WYSIWYG features are enabled.
class MdWysiwygConfig {
  /// Display mode for formatting marks.
  ///
  /// - `'auto'` — WYSIWYG mode: marks are hidden when cursor is outside
  ///   their AST element range, and shown when cursor is within range.
  /// - `'show'` — Source mode: all marks are always visible.
  final String formattingDisplayMode;

  /// Whether to hide inline marks (`**`, `*`, `` ` ``, `~~`, `==`, `\`).
  final bool hideInlineMarks;

  /// Whether to hide block marks (heading `#`, blockquote `>`, code fences).
  final bool hideBlockMarks;

  /// Whether to auto-continue lists and blockquotes on Enter.
  final bool autoContinueList;

  /// The [TextStyle] applied to hidden marks.
  ///
  /// Defaults to a near-zero-width style that makes characters effectively
  /// invisible while preserving their position in the text buffer.
  final TextStyle hiddenStyle;

  /// Default near-zero-width style for hiding marks.
  static const TextStyle defaultHiddenStyle = TextStyle(
    fontSize: 0.01,
    height: 0.01,
    letterSpacing: -1,
    color: Color(0x00000000),
  );

  const MdWysiwygConfig({
    this.formattingDisplayMode = 'auto',
    this.hideInlineMarks = true,
    this.hideBlockMarks = true,
    this.autoContinueList = true,
    this.hiddenStyle = defaultHiddenStyle,
  });

  /// Whether WYSIWYG mode is active (auto mode).
  bool get isAutoMode => formattingDisplayMode == 'auto';

  MdWysiwygConfig copyWith({
    String? formattingDisplayMode,
    bool? hideInlineMarks,
    bool? hideBlockMarks,
    bool? autoContinueList,
    TextStyle? hiddenStyle,
  }) {
    return MdWysiwygConfig(
      formattingDisplayMode:
          formattingDisplayMode ?? this.formattingDisplayMode,
      hideInlineMarks: hideInlineMarks ?? this.hideInlineMarks,
      hideBlockMarks: hideBlockMarks ?? this.hideBlockMarks,
      autoContinueList: autoContinueList ?? this.autoContinueList,
      hiddenStyle: hiddenStyle ?? this.hiddenStyle,
    );
  }
}
