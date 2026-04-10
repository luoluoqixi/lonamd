import 'dart:ui' show Color;

import 'package:flutter/painting.dart';

/// Default heading scale factors for h1–h6.
const List<double> defaultHeadingScales = [
  1.802,
  1.502,
  1.300,
  1.150,
  1.0,
  1.0
];

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

  /// Whether to enable heading font size scaling (h1=1.8x, h2=1.5x, etc.).
  final bool enableHeadingScale;

  /// Scale factors for h1–h6 headings.
  /// Must contain exactly 6 elements.
  final List<double> headingScales;

  /// Whether to render a background behind fenced code blocks.
  final bool enableCodeBlockBackground;

  /// Custom background color for code blocks. Null uses theme default.
  final Color? codeBlockBackgroundColor;

  /// Whether to render a horizontal line for HR markers.
  final bool enableHrLine;

  /// Whether to replace list bullet markers with visual symbols.
  final bool enableListBulletReplace;

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
    this.enableHeadingScale = true,
    this.headingScales = defaultHeadingScales,
    this.enableCodeBlockBackground = true,
    this.codeBlockBackgroundColor,
    this.enableHrLine = true,
    this.enableListBulletReplace = true,
  });

  /// Whether WYSIWYG mode is active (auto mode).
  bool get isAutoMode => formattingDisplayMode == 'auto';

  MdWysiwygConfig copyWith({
    String? formattingDisplayMode,
    bool? hideInlineMarks,
    bool? hideBlockMarks,
    bool? autoContinueList,
    TextStyle? hiddenStyle,
    bool? enableHeadingScale,
    List<double>? headingScales,
    bool? enableCodeBlockBackground,
    Color? codeBlockBackgroundColor,
    bool? enableHrLine,
    bool? enableListBulletReplace,
  }) {
    return MdWysiwygConfig(
      formattingDisplayMode:
          formattingDisplayMode ?? this.formattingDisplayMode,
      hideInlineMarks: hideInlineMarks ?? this.hideInlineMarks,
      hideBlockMarks: hideBlockMarks ?? this.hideBlockMarks,
      autoContinueList: autoContinueList ?? this.autoContinueList,
      hiddenStyle: hiddenStyle ?? this.hiddenStyle,
      enableHeadingScale: enableHeadingScale ?? this.enableHeadingScale,
      headingScales: headingScales ?? this.headingScales,
      enableCodeBlockBackground:
          enableCodeBlockBackground ?? this.enableCodeBlockBackground,
      codeBlockBackgroundColor:
          codeBlockBackgroundColor ?? this.codeBlockBackgroundColor,
      enableHrLine: enableHrLine ?? this.enableHrLine,
      enableListBulletReplace:
          enableListBulletReplace ?? this.enableListBulletReplace,
    );
  }
}
