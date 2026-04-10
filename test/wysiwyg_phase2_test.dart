import 'package:flutter_test/flutter_test.dart';
import 'package:lonamd/highlight.dart';
import 'package:lonamd/src/markdown/md_block_decoration.dart';
import 'package:lonamd/src/markdown/md_extension.dart';
import 'package:lonamd/src/markdown/md_highlight.dart';
import 'package:lonamd/src/markdown/md_wysiwyg_config.dart';
import 'package:lonamd/src/markdown/md_wysiwyg_state.dart';

// ============================================================
// Helpers
// ============================================================

/// Populate metadata from markdown code and return the state.
MdWysiwygState populateState(String code, [MdWysiwygConfig? config]) {
  final plugin = MdHighlightPlugin();
  final state = MdWysiwygState(config: config ?? const MdWysiwygConfig());
  plugin.populateMetadata(code, state);
  return state;
}

/// Highlight markdown and collect per-line tokens.
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
      scope = '$parent-${node.scope!}';
    }
    scope = scope?.split('.')[0];
    _scopeStack.add(scope);
  }

  @override
  void closeNode(DataNode node) {
    _scopeStack.removeLast();
  }
}

// ============================================================
// Tests
// ============================================================

void main() {
  // 9.1 Heading scope tests
  group('heading scope differentiation', () {
    test('atx headings h1-h6 produce section-hN scopes', () {
      final code = '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6';
      final lines = highlightMarkdown(code);

      // Line 0: # H1 → section-h1 scope
      expect(lines[0].any((t) => t.scope == 'section-h1'), isTrue);
      // Line 1: ## H2 → section-h2 scope
      expect(lines[1].any((t) => t.scope == 'section-h2'), isTrue);
      // Line 2: ### H3 → section-h3 scope
      expect(lines[2].any((t) => t.scope == 'section-h3'), isTrue);
      // Line 3: #### H4 → section-h4 scope
      expect(lines[3].any((t) => t.scope == 'section-h4'), isTrue);
      // Line 4: ##### H5 → section-h5 scope
      expect(lines[4].any((t) => t.scope == 'section-h5'), isTrue);
      // Line 5: ###### H6 → section-h6-md-mark scope for mark
      expect(lines[5].any((t) => t.scope?.contains('section-h6') ?? false),
          isTrue);
    });

    test('heading marks use compound scope section-hN-md-mark', () {
      final code = '## Hello';
      final lines = highlightMarkdown(code);
      // The ## mark should have scope section-h2-md-mark
      expect(
          lines[0].any(
              (t) => t.scope == 'section-h2-md-mark' && t.text.contains('#')),
          isTrue);
    });
  });

  // 9.2 lineMetadata population tests
  group('lineMetadata population', () {
    test('heading lines get correct type and scale', () {
      final code = '# H1\n## H2\n### H3\n#### H4\nplain';
      final state = populateState(code);
      expect(state.lineMetadata[0]?.type, MdLineType.heading1);
      expect(state.lineMetadata[0]?.heightScale, 1.802);
      expect(state.lineMetadata[1]?.type, MdLineType.heading2);
      expect(state.lineMetadata[1]?.heightScale, 1.502);
      expect(state.lineMetadata[2]?.type, MdLineType.heading3);
      expect(state.lineMetadata[2]?.heightScale, 1.300);
      expect(state.lineMetadata[3]?.type, MdLineType.heading4);
      expect(state.lineMetadata[3]?.heightScale, 1.150);
      // Line 4 (plain text) should not have metadata
      expect(state.lineMetadata[4], isNull);
    });

    test('code block lines get codeBlock type', () {
      final code = '```\ncode line 1\ncode line 2\n```';
      final state = populateState(code);
      expect(state.lineMetadata[0]?.type, MdLineType.codeBlock);
      expect(state.lineMetadata[1]?.type, MdLineType.codeBlock);
      expect(state.lineMetadata[2]?.type, MdLineType.codeBlock);
      expect(state.lineMetadata[3]?.type, MdLineType.codeBlock);
    });

    test('horizontal rule gets HR type', () {
      final code = 'above\n\n---\n\nbelow';
      final state = populateState(code);
      expect(state.lineMetadata[2]?.type, MdLineType.horizontalRule);
    });

    test('list items get list type', () {
      final code = '- item 1\n- item 2';
      final state = populateState(code);
      expect(state.lineMetadata[0]?.type, MdLineType.list);
      expect(state.lineMetadata[1]?.type, MdLineType.list);
    });
  });

  // 9.3 blockDecorations population tests
  group('blockDecorations population', () {
    test('fenced code block produces codeBlock decoration', () {
      final code = '```dart\nprint("hello");\n```';
      final state = populateState(code);
      final codeBlocks = state.blockDecorations
          .where((d) => d.type == MdBlockDecorationType.codeBlock)
          .toList();
      expect(codeBlocks, hasLength(1));
      expect(codeBlocks[0].startLine, 0);
      expect(codeBlocks[0].endLine, 2);
    });

    test('horizontal rule produces HR decoration', () {
      final code = 'text\n\n---\n\ntext';
      final state = populateState(code);
      final hrs = state.blockDecorations
          .where((d) => d.type == MdBlockDecorationType.horizontalRule)
          .toList();
      expect(hrs, hasLength(1));
      expect(hrs[0].startLine, 2);
    });

    test('unordered list produces listBullet decoration with marker info', () {
      final code = '- item 1\n- item 2';
      final state = populateState(code);
      final bullets = state.blockDecorations
          .where((d) => d.type == MdBlockDecorationType.listBullet)
          .toList();
      expect(bullets.length, greaterThanOrEqualTo(1));
      expect(bullets[0].startLine, 0);
      expect(bullets[0].markerColumn, 0);
      expect(bullets[0].markerLength, 1); // "-" char only
      if (bullets.length > 1) {
        expect(bullets[1].startLine, 1);
      }
    });

    test('task list produces task decorations', () {
      final code = '- [ ] unchecked\n- [x] checked';
      final state = populateState(code);
      final tasks = state.blockDecorations
          .where((d) =>
              d.type == MdBlockDecorationType.taskUnchecked ||
              d.type == MdBlockDecorationType.taskChecked)
          .toList();
      expect(tasks.any((t) => t.type == MdBlockDecorationType.taskUnchecked),
          isTrue);
      expect(tasks.any((t) => t.type == MdBlockDecorationType.taskChecked),
          isTrue);
    });
  });

  // 9.5 MdWysiwygConfig new fields tests
  group('MdWysiwygConfig phase2 fields', () {
    test('default config enables all phase2 features', () {
      const config = MdWysiwygConfig();
      expect(config.enableHeadingScale, isTrue);
      expect(config.headingScales, hasLength(6));
      expect(config.enableCodeBlockBackground, isTrue);
      expect(config.codeBlockBackgroundColor, isNull);
      expect(config.enableHrLine, isTrue);
      expect(config.enableListBulletReplace, isTrue);
    });

    test('copyWith preserves phase2 fields', () {
      const config = MdWysiwygConfig(enableHeadingScale: false);
      final copy = config.copyWith(enableHrLine: false);
      expect(copy.enableHeadingScale, isFalse);
      expect(copy.enableHrLine, isFalse);
      expect(copy.enableCodeBlockBackground, isTrue);
    });

    test('custom heading scales are used', () {
      final scales = [2.0, 1.8, 1.5, 1.3, 1.1, 1.0];
      final config = MdWysiwygConfig(headingScales: scales);
      expect(config.headingScales, equals(scales));
    });
  });

  // 9.6 List symbol hiding tests
  group('list bullet scope', () {
    test('list mark gets bullet scope', () {
      final code = '- item';
      final lines = highlightMarkdown(code);
      expect(lines[0].any((t) => t.scope == 'bullet'), isTrue);
    });

    test('task marker gets bullet scope', () {
      final code = '- [ ] task';
      final lines = highlightMarkdown(code);
      expect(lines[0].any((t) => t.scope == 'bullet'), isTrue);
    });
  });
}
