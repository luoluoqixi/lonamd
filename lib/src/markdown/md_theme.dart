import 'package:flutter/painting.dart';
import 'package:lonamd/highlight/languages/markdown.dart';
import 'package:lonamd/lonamd.dart';

import 'md_block_context.dart';
import 'md_highlight.dart';

/// Default scope → TextStyle map for Markdown.
///
/// These map the scope names used by [MdHighlightPlugin] to visual styles.
/// You can override any of these by passing a custom theme map to
/// [mdHighlightTheme].
///
/// Scopes used:
/// - `section` — headings and table headers
/// - `strong` — bold text
/// - `emphasis` — italic text
/// - `code` — code blocks, inline code, code content
/// - `link` — links, URLs, images
/// - `quote` — blockquote content
/// - `bullet` — list markers, task markers
/// - `meta` — syntax marks (# > ``` ~~ == delimiters etc.)
/// - `string` — code info, link title
/// - `symbol` — link labels, link references
/// - `comment` — HTML comments
/// - `deletion` — strikethrough text
/// - `addition` — highlight text
Map<String, TextStyle> defaultMdLightTheme() {
  return {
    'section': const TextStyle(
      color: Color(0xFF0550AE),
      fontWeight: FontWeight.bold,
    ),
    'strong': const TextStyle(
      fontWeight: FontWeight.bold,
    ),
    'emphasis': const TextStyle(
      fontStyle: FontStyle.italic,
    ),
    'code': const TextStyle(
      color: Color(0xFF6639BA),
      fontFamily: 'monospace',
    ),
    'link': const TextStyle(
      color: Color(0xFF0969DA),
      decoration: TextDecoration.underline,
    ),
    'quote': const TextStyle(
      color: Color(0xFF57606A),
      fontStyle: FontStyle.italic,
    ),
    'bullet': const TextStyle(
      color: Color(0xFFCF222E),
      fontWeight: FontWeight.bold,
    ),
    'meta': const TextStyle(
      color: Color(0xFF8250DF),
    ),
    'md-mark': const TextStyle(
      color: Color(0xFF8250DF),
    ),
    'string': const TextStyle(
      color: Color(0xFF0A3069),
    ),
    'symbol': const TextStyle(
      color: Color(0xFF0550AE),
    ),
    'comment': const TextStyle(
      color: Color(0xFF6E7781),
      fontStyle: FontStyle.italic,
    ),
    'deletion': const TextStyle(
      color: Color(0xFF82071E),
      decoration: TextDecoration.lineThrough,
    ),
    'addition': const TextStyle(
      color: Color(0xFF116329),
      backgroundColor: Color(0x33ACE2AC),
    ),
  };
}

/// Default dark theme for Markdown.
Map<String, TextStyle> defaultMdDarkTheme() {
  return {
    'section': const TextStyle(
      color: Color(0xFF79C0FF),
      fontWeight: FontWeight.bold,
    ),
    'strong': const TextStyle(
      fontWeight: FontWeight.bold,
    ),
    'emphasis': const TextStyle(
      fontStyle: FontStyle.italic,
    ),
    'code': const TextStyle(
      color: Color(0xFFD2A8FF),
      fontFamily: 'monospace',
    ),
    'link': const TextStyle(
      color: Color(0xFF58A6FF),
      decoration: TextDecoration.underline,
    ),
    'quote': const TextStyle(
      color: Color(0xFF8B949E),
      fontStyle: FontStyle.italic,
    ),
    'bullet': const TextStyle(
      color: Color(0xFFFF7B72),
      fontWeight: FontWeight.bold,
    ),
    'meta': const TextStyle(
      color: Color(0xFFBC8CFF),
    ),
    'md-mark': const TextStyle(
      color: Color(0xFFBC8CFF),
    ),
    'string': const TextStyle(
      color: Color(0xFFA5D6FF),
    ),
    'symbol': const TextStyle(
      color: Color(0xFF79C0FF),
    ),
    'comment': const TextStyle(
      color: Color(0xFF8B949E),
      fontStyle: FontStyle.italic,
    ),
    'deletion': const TextStyle(
      color: Color(0xFFFFA198),
      decoration: TextDecoration.lineThrough,
    ),
    'addition': const TextStyle(
      color: Color(0xFF7EE787),
      backgroundColor: Color(0x332EA043),
    ),
  };
}

/// Build a [CodeHighlightTheme] for Markdown with AST-based highlighting.
///
/// The returned theme includes [MdHighlightPlugin] which replaces
/// Re-Highlight's regex-based Markdown highlighting with our AST parser.
///
/// [theme] — scope→style map. Defaults to [defaultMdLightTheme].
/// [parser] — custom [MdMarkdownParserImpl]. Defaults to [gfmMarkdownParser].
CodeHighlightTheme mdHighlightTheme({
  Map<String, TextStyle>? theme,
  MdMarkdownParserImpl? parser,
}) {
  return CodeHighlightTheme(
    languages: {'markdown': langMarkdown.themeMode},
    theme: theme ?? defaultMdLightTheme(),
    plugins: [MdHighlightPlugin(parser)],
  );
}
