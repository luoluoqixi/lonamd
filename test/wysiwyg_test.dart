import 'package:flutter_test/flutter_test.dart';
import 'package:lonamd/lonamd.dart';
import 'package:lonamd/src/markdown/md_decoration.dart';
import 'package:lonamd/src/markdown/md_commands.dart';
import 'package:lonamd/src/markdown/md_wysiwyg_config.dart';
import 'package:lonamd/src/markdown/md_wysiwyg_state.dart';

// Re-use the highlight test helper
import 'package:lonamd/highlight.dart';
import 'package:lonamd/src/markdown/md_highlight.dart';
import 'package:lonamd/src/markdown/md_extension.dart';

/// Helper: Highlight code and collect per-line tokens as (text, scope?) pairs.
List<List<_Token>> highlightMarkdown(String code) {
  final highlight = Highlight();
  highlight.registerLanguage('markdown', Mode(name: 'Markdown'));
  highlight.addPlugin(MdHighlightPlugin());

  final result = highlight.highlight(code: code, language: 'markdown');

  final renderer = _TestLineRenderer();
  result.render(renderer);
  return renderer.lines;
}

class _Token {
  final String text;
  final String? scope;
  _Token(this.text, this.scope);

  @override
  String toString() => scope != null ? '[$scope: "$text"]' : '"$text"';
}

class _TestLineRenderer implements HighlightRenderer {
  final List<List<_Token>> lines = [[]];
  final List<String?> _scopeStack = [];

  String? get _currentScope => _scopeStack.isEmpty ? null : _scopeStack.last;

  @override
  void addText(String text) {
    final parts = text.split('\n');
    lines.last.add(_Token(parts.first, _currentScope));
    for (int i = 1; i < parts.length; i++) {
      lines.add([_Token(parts[i], _currentScope)]);
    }
  }

  @override
  void openNode(DataNode node) {
    final parent = _scopeStack.isEmpty ? null : _scopeStack.last;
    String? scope;
    if (parent == null || node.scope == null) {
      scope = node.scope;
    } else {
      scope = '${node.scope}-$parent';
    }
    _scopeStack.add(scope);
  }

  @override
  void closeNode(DataNode node) {
    _scopeStack.removeLast();
  }
}

void main() {
  // ============================================================
  // 8.1 isSelectRange unit tests
  // ============================================================
  group('isSelectRange', () {
    // Helper to build CodeLines from a list of strings.
    CodeLines makeLines(List<String> texts) {
      return CodeLines.of(texts.map((t) => CodeLine(t)).toList());
    }

    test('cursor inside range returns true', () {
      // "hello world" — test range [2, 7) with cursor at offset 4
      final lines = makeLines(['hello world']);
      final sel = CodeLineSelection.collapsed(index: 0, offset: 4);
      expect(isSelectRange(sel, lines, 2, 7), isTrue);
    });

    test('cursor outside range returns false', () {
      final lines = makeLines(['hello world']);
      final sel = CodeLineSelection.collapsed(index: 0, offset: 0);
      expect(isSelectRange(sel, lines, 5, 10), isFalse);
    });

    test('cursor at range start boundary returns true', () {
      final lines = makeLines(['hello world']);
      final sel = CodeLineSelection.collapsed(index: 0, offset: 5);
      // Range [5, 10): cursor at 5 means selFrom=5, selTo=5 → 5 < 10 && 10 > 5 → false
      // Actually collapsed selection: selFrom=selTo=5 → 5 < 10 is true, 10 > 5? from < selTo: 5 < 5? No → false
      expect(isSelectRange(sel, lines, 5, 10), isFalse);
    });

    test('selection overlapping range returns true', () {
      final lines = makeLines(['hello world']);
      final sel = CodeLineSelection(
        baseIndex: 0,
        baseOffset: 3,
        extentIndex: 0,
        extentOffset: 8,
      );
      expect(isSelectRange(sel, lines, 5, 10), isTrue);
    });

    test('selection not overlapping range returns false', () {
      final lines = makeLines(['hello world']);
      final sel = CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 3,
      );
      expect(isSelectRange(sel, lines, 5, 10), isFalse);
    });

    test('multi-line document offset calculation', () {
      // Line 0: "abc" (len 3 + 1 newline = 4)
      // Line 1: "defgh" (starts at doc offset 4)
      final lines = makeLines(['abc', 'defgh']);
      // Cursor on line 1, offset 2 → doc offset = 4 + 2 = 6
      final sel = CodeLineSelection.collapsed(index: 1, offset: 2);
      // Range [5, 8) covers doc offsets 5-7 → cursor at 6 is inside
      expect(isSelectRange(sel, lines, 5, 8), isTrue);
    });

    test('cross-line selection intersects range', () {
      final lines = makeLines(['abc', 'defgh', 'xyz']);
      // Selection from line 0 offset 1 to line 2 offset 1
      final sel = CodeLineSelection(
        baseIndex: 0,
        baseOffset: 1,
        extentIndex: 2,
        extentOffset: 1,
      );
      // Range on line 1 [4, 9): should intersect
      expect(isSelectRange(sel, lines, 4, 9), isTrue);
    });
  });

  // ============================================================
  // 8.1b isSelectLine unit tests
  // ============================================================
  group('isSelectLine', () {
    test('cursor on same line returns true', () {
      final sel = CodeLineSelection.collapsed(index: 2, offset: 5);
      expect(isSelectLine(sel, 2), isTrue);
    });

    test('cursor on different line returns false', () {
      final sel = CodeLineSelection.collapsed(index: 2, offset: 5);
      expect(isSelectLine(sel, 0), isFalse);
    });

    test('multi-line selection includes middle line', () {
      final sel = CodeLineSelection(
        baseIndex: 1,
        baseOffset: 0,
        extentIndex: 3,
        extentOffset: 5,
      );
      expect(isSelectLine(sel, 2), isTrue);
      expect(isSelectLine(sel, 0), isFalse);
      expect(isSelectLine(sel, 4), isFalse);
    });
  });

  // ============================================================
  // 8.2 Inline mark hiding highlight tests
  // ============================================================
  group('inline mark hiding - highlight scopes', () {
    test('bold marks get md-mark scope', () {
      final lines = highlightMarkdown('**bold**');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue,
          reason: 'Bold opening/closing marks should have md-mark scope');
    });

    test('italic marks get md-mark scope', () {
      final lines = highlightMarkdown('*italic*');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('strikethrough marks get md-mark scope', () {
      final lines = highlightMarkdown('~~strike~~');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('highlight marks get md-mark scope', () {
      final lines = highlightMarkdown('==highlight==');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('inline code marks get md-mark scope', () {
      final lines = highlightMarkdown('`code`');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('heading mark gets md-mark scope', () {
      final lines = highlightMarkdown('# Heading');
      expect(lines[0].any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('escape gets meta scope (not md-mark)', () {
      final lines = highlightMarkdown(r'\*escaped\*');
      // Escape characters should keep "meta" scope, not "md-mark"
      final metaTokens = lines[0].where((t) => t.scope == 'meta').toList();
      expect(metaTokens.isNotEmpty, isTrue,
          reason: 'Escape characters should use meta scope');
    });
  });

  // ============================================================
  // 8.3 Block-level mark hiding highlight tests
  // ============================================================
  group('block mark hiding - highlight scopes', () {
    test('blockquote mark gets md-mark scope', () {
      final lines = highlightMarkdown('> quoted text');
      final quoteTokens = lines[0].where((t) => t.text.contains('>')).toList();
      expect(
          quoteTokens.any((t) => t.scope?.contains('md-mark') == true), isTrue);
    });

    test('horizontal rule gets md-mark scope', () {
      final lines = highlightMarkdown('---');
      final hrTokens = lines[0].where((t) => t.text == '---').toList();
      expect(hrTokens.isNotEmpty, isTrue);
      expect(hrTokens.first.scope, contains('md-mark'));
    });
  });

  // ============================================================
  // 8.4 Focus-aware / WYSIWYG state tests
  // ============================================================
  group('MdWysiwygState', () {
    test('initial state has default selection', () {
      final state = MdWysiwygState(config: const MdWysiwygConfig());
      expect(state.selection, isNotNull);
      expect(state.hasFocus, isFalse);
    });

    test('updateSelection returns affected lines', () {
      final state = MdWysiwygState(config: const MdWysiwygConfig());
      // First update: cursor on line 5
      final affected = state
          .updateSelection(CodeLineSelection.collapsed(index: 5, offset: 0));
      expect(affected.contains(5), isTrue);
    });

    test('updateSelection returns both old and new lines', () {
      final state = MdWysiwygState(config: const MdWysiwygConfig());
      state.updateSelection(CodeLineSelection.collapsed(index: 2, offset: 0));
      // Move to line 7
      final affected = state
          .updateSelection(CodeLineSelection.collapsed(index: 7, offset: 0));
      expect(affected.contains(2), isTrue,
          reason: 'old line should be affected');
      expect(affected.contains(7), isTrue,
          reason: 'new line should be affected');
    });

    test('updateFocus returns true when focus changes', () {
      final state = MdWysiwygState(config: const MdWysiwygConfig());
      expect(state.updateFocus(true), isTrue);
      expect(state.hasFocus, isTrue);
      expect(state.updateFocus(true), isFalse); // No change
      expect(state.updateFocus(false), isTrue);
      expect(state.hasFocus, isFalse);
    });

    test('show mode means isAutoMode is false', () {
      final state = MdWysiwygState(
        config: const MdWysiwygConfig(formattingDisplayMode: 'show'),
      );
      expect(state.config.isAutoMode, isFalse);
    });
  });

  // ============================================================
  // 8.5 Format toggle command tests
  // ============================================================
  group('toggleInlineFormat', () {
    CodeLineEditingController makeController(String text, {int? offset}) {
      final controller = CodeLineEditingController();
      controller.text = text;
      if (offset != null) {
        controller.selection =
            CodeLineSelection.collapsed(index: 0, offset: offset);
      }
      return controller;
    }

    test('insert bold marks on empty cursor', () {
      final c = makeController('hello world', offset: 5);
      toggleInlineFormat(c, '**');
      expect(c.codeLines[0].text, 'hello**** world');
      expect(c.selection.startOffset, 7); // Cursor between ** and **
    });

    test('remove bold marks when cursor inside empty marks', () {
      final c = makeController('hello****world', offset: 7);
      toggleInlineFormat(c, '**');
      expect(c.codeLines[0].text, 'helloworld');
      expect(c.selection.startOffset, 5);
    });

    test('wrap selected text with marks', () {
      final c = makeController('hello world');
      c.selection = CodeLineSelection(
          baseIndex: 0, baseOffset: 6, extentIndex: 0, extentOffset: 11);
      toggleInlineFormat(c, '**');
      expect(c.codeLines[0].text, 'hello **world**');
      expect(c.selection.startOffset, 8);
      expect(c.selection.endOffset, 13);
    });

    test('unwrap selected text when already formatted', () {
      final c = makeController('hello **world**');
      c.selection = CodeLineSelection(
          baseIndex: 0, baseOffset: 8, extentIndex: 0, extentOffset: 13);
      toggleInlineFormat(c, '**');
      expect(c.codeLines[0].text, 'hello world');
      expect(c.selection.startOffset, 6);
      expect(c.selection.endOffset, 11);
    });

    test('italic toggle with single asterisk', () {
      final c = makeController('some text', offset: 4);
      toggleInlineFormat(c, '*');
      expect(c.codeLines[0].text, 'some** text');
      expect(c.selection.startOffset, 5);
    });

    test('strikethrough toggle', () {
      final c = makeController('hello world');
      c.selection = CodeLineSelection(
          baseIndex: 0, baseOffset: 0, extentIndex: 0, extentOffset: 5);
      toggleInlineFormat(c, '~~');
      expect(c.codeLines[0].text, '~~hello~~ world');
    });

    test('highlight toggle', () {
      final c = makeController('hello world');
      c.selection = CodeLineSelection(
          baseIndex: 0, baseOffset: 0, extentIndex: 0, extentOffset: 5);
      toggleInlineFormat(c, '==');
      expect(c.codeLines[0].text, '==hello== world');
    });
  });

  // ============================================================
  // 8.6 Enter continuation tests
  // ============================================================
  group('handleMarkdownNewLine', () {
    CodeLineEditingController makeController(String text, int offset) {
      final c = CodeLineEditingController();
      c.text = text;
      c.selection = CodeLineSelection.collapsed(index: 0, offset: offset);
      return c;
    }

    test('continues unordered list with dash', () {
      final c = makeController('- item one', 10);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '- item one');
      expect(c.codeLines[1].text, '- ');
      expect(c.selection.startIndex, 1);
      expect(c.selection.startOffset, 2);
    });

    test('continues unordered list with asterisk', () {
      final c = makeController('* item', 6);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '* ');
    });

    test('continues unordered list with plus', () {
      final c = makeController('+ item', 6);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '+ ');
    });

    test('removes empty unordered list item', () {
      final c = makeController('- ', 2);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '');
      expect(c.selection.startOffset, 0);
    });

    test('continues ordered list with incremented number', () {
      final c = makeController('1. first item', 13);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '2. ');
    });

    test('continues ordered list with parenthesis separator', () {
      final c = makeController('3) item', 7);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '4) ');
    });

    test('removes empty ordered list item', () {
      final c = makeController('1. ', 3);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '');
    });

    test('continues task list', () {
      final c = makeController('- [ ] task one', 14);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '- [ ] ');
    });

    test('removes empty task list item', () {
      final c = makeController('- [ ] ', 6);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '');
    });

    test('continues blockquote', () {
      final c = makeController('> some quoted text', 18);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '> ');
    });

    test('removes empty blockquote', () {
      final c = makeController('> ', 2);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '');
    });

    test('preserves indentation in nested list', () {
      final c = makeController('  - nested item', 15);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[1].text, '  - ');
    });

    test('returns false for plain text', () {
      final c = makeController('hello world', 11);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isFalse);
    });

    test('returns false for non-collapsed selection', () {
      final c = CodeLineEditingController();
      c.text = '- item';
      c.selection = CodeLineSelection(
          baseIndex: 0, baseOffset: 0, extentIndex: 0, extentOffset: 4);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isFalse);
    });

    test('splits text at cursor in list', () {
      final c = makeController('- hello world', 8);
      final handled = handleMarkdownNewLine(c);
      expect(handled, isTrue);
      expect(c.codeLines[0].text, '- hello ');
      expect(c.codeLines[1].text, '- world');
      expect(c.selection.startIndex, 1);
      expect(c.selection.startOffset, 2);
    });
  });

  // ============================================================
  // 8.7 Config tests
  // ============================================================
  group('MdWysiwygConfig', () {
    test('default config has auto mode', () {
      const config = MdWysiwygConfig();
      expect(config.isAutoMode, isTrue);
      expect(config.formattingDisplayMode, 'auto');
    });

    test('show mode disables auto', () {
      const config = MdWysiwygConfig(formattingDisplayMode: 'show');
      expect(config.isAutoMode, isFalse);
    });

    test('default config enables all features', () {
      const config = MdWysiwygConfig();
      expect(config.hideInlineMarks, isTrue);
      expect(config.hideBlockMarks, isTrue);
      expect(config.autoContinueList, isTrue);
    });

    test('can selectively disable features', () {
      const config = MdWysiwygConfig(
        hideInlineMarks: false,
        autoContinueList: false,
      );
      expect(config.hideInlineMarks, isFalse);
      expect(config.autoContinueList, isFalse);
      expect(config.hideBlockMarks, isTrue);
    });

    test('copyWith preserves unchanged values', () {
      const original = MdWysiwygConfig(
        hideInlineMarks: false,
        autoContinueList: false,
      );
      final copy = original.copyWith(hideInlineMarks: true);
      expect(copy.hideInlineMarks, isTrue);
      expect(copy.autoContinueList, isFalse); // Preserved
      expect(copy.hideBlockMarks, isTrue); // Preserved
    });
  });
}
