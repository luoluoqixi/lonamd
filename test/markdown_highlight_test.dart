import 'package:lonamd/highlight.dart';
import 'package:lonamd/src/markdown/md_highlight.dart';
import 'package:lonamd/src/markdown/md_extension.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Minimal renderer that collects tokens per line, similar to _HighlightLineRenderer.
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
    if (_scopeStack.isNotEmpty) _scopeStack.removeLast();
  }
}

/// Find first token in any line with matching scope
_Token? findScope(List<List<_Token>> lines, String scope) {
  for (final line in lines) {
    for (final t in line) {
      if (t.scope == scope) return t;
    }
  }
  return null;
}

/// Check if any token has a scope that starts with the given prefix
bool hasScope(List<List<_Token>> lines, String scope) {
  return findScope(lines, scope) != null;
}

/// Check if any token has a scope containing the given substring
bool hasScopeContaining(List<List<_Token>> lines, String part) {
  for (final line in lines) {
    for (final t in line) {
      if (t.scope != null && t.scope!.contains(part)) return true;
    }
  }
  return false;
}

void main() {
  group('MdHighlightPlugin', () {
    test('intercepts markdown highlighting', () {
      final lines = highlightMarkdown('Hello world');
      expect(lines.length, 1);
      // Should have at least one token
      expect(lines[0].isNotEmpty, isTrue);
    });

    test('heading gets section scope', () {
      final lines = highlightMarkdown('# Hello');
      expect(hasScopeContaining(lines, 'section'), isTrue);
    });

    test('heading mark gets md-mark scope', () {
      final lines = highlightMarkdown('# Hello');
      // The # mark should be md-mark inside section
      expect(hasScopeContaining(lines, 'md-mark'), isTrue);
    });

    test('emphasis gets emphasis scope', () {
      final lines = highlightMarkdown('*italic*');
      expect(hasScopeContaining(lines, 'emphasis'), isTrue);
    });

    test('strong gets strong scope', () {
      final lines = highlightMarkdown('**bold**');
      expect(hasScopeContaining(lines, 'strong'), isTrue);
    });

    test('inline code gets code scope', () {
      final lines = highlightMarkdown('some `code` here');
      expect(hasScopeContaining(lines, 'code'), isTrue);
    });

    test('fenced code block gets code scope', () {
      final lines = highlightMarkdown('```\ncode\n```');
      expect(hasScopeContaining(lines, 'code'), isTrue);
    });

    test('link gets link scope', () {
      final lines = highlightMarkdown('[text](http://example.com)');
      expect(hasScopeContaining(lines, 'link'), isTrue);
    });

    test('blockquote gets quote scope', () {
      final lines = highlightMarkdown('> quoted text');
      expect(hasScopeContaining(lines, 'quote'), isTrue);
    });

    test('list marker gets bullet scope', () {
      final lines = highlightMarkdown('- item one\n- item two');
      expect(hasScopeContaining(lines, 'bullet'), isTrue);
    });

    test('horizontal rule gets md-mark scope', () {
      final lines = highlightMarkdown('---');
      expect(hasScopeContaining(lines, 'md-mark'), isTrue);
    });

    test('strikethrough gets deletion scope', () {
      final lines = highlightMarkdown('~~deleted~~');
      expect(hasScopeContaining(lines, 'deletion'), isTrue);
    });

    test('highlight gets addition scope', () {
      final lines = highlightMarkdown('==highlighted==');
      expect(hasScopeContaining(lines, 'addition'), isTrue);
    });

    test('task marker gets bullet scope', () {
      final lines = highlightMarkdown('- [ ] todo');
      expect(hasScopeContaining(lines, 'bullet'), isTrue);
    });

    test('table header gets section scope', () {
      final lines = highlightMarkdown('| a | b |\n| --- | --- |\n| 1 | 2 |');
      expect(hasScopeContaining(lines, 'section'), isTrue);
    });

    test('multiline document produces correct line count', () {
      final code = '# Title\n\nParagraph\n\n- item';
      final lines = highlightMarkdown(code);
      expect(lines.length, 5); // 5 lines including blanks
    });

    test('does not intercept non-markdown language', () {
      final highlight = Highlight();
      highlight.registerLanguage('dart', Mode(name: 'Dart'));
      highlight.addPlugin(MdHighlightPlugin());

      // Should fall through to standard highlighting (no error)
      final result =
          highlight.highlight(code: 'void main() {}', language: 'dart');
      expect(result.language, 'dart');
    });
  });

  group('HighlightResult.build', () {
    test('creates valid result with scoped tokens', () {
      final result = HighlightResult.build('hello world', (emitter) {
        emitter.startScope('keyword');
        emitter.addText('hello');
        emitter.endScope();
        emitter.addText(' ');
        emitter.startScope('string');
        emitter.addText('world');
        emitter.endScope();
      });

      final renderer = _TestLineRenderer();
      result.render(renderer);

      expect(renderer.lines.length, 1);
      expect(renderer.lines[0].length, 3);
      expect(renderer.lines[0][0].text, 'hello');
      expect(renderer.lines[0][0].scope, 'keyword');
      expect(renderer.lines[0][1].text, ' ');
      expect(renderer.lines[0][1].scope, isNull);
      expect(renderer.lines[0][2].text, 'world');
      expect(renderer.lines[0][2].scope, 'string');
    });

    test('handles newlines correctly', () {
      final result = HighlightResult.build('line1\nline2', (emitter) {
        emitter.addText('line1\nline2');
      });

      final renderer = _TestLineRenderer();
      result.render(renderer);

      expect(renderer.lines.length, 2);
      expect(renderer.lines[0][0].text, 'line1');
      expect(renderer.lines[1][0].text, 'line2');
    });
  });

  group('Combined AST + Highlight', () {
    test('complex document produces correct scopes', () {
      final code = '''# GFM Demo

This is **bold** and *italic* and `code`.

> A quote

- [ ] Task item
- Normal item

~~strike~~ and ==highlight==

| h1 | h2 |
| -- | -- |
| a  | b  |''';
      final lines = highlightMarkdown(code);

      // Line 0: heading
      expect(hasScopeContaining(lines, 'section'), isTrue);
      // Has bold, italic, code
      expect(hasScopeContaining(lines, 'strong'), isTrue);
      expect(hasScopeContaining(lines, 'emphasis'), isTrue);
      expect(hasScopeContaining(lines, 'code'), isTrue);
      // Has quote
      expect(hasScopeContaining(lines, 'quote'), isTrue);
      // Has bullet
      expect(hasScopeContaining(lines, 'bullet'), isTrue);
      // Has strikethrough and highlight
      expect(hasScopeContaining(lines, 'deletion'), isTrue);
      expect(hasScopeContaining(lines, 'addition'), isTrue);
    });
  });
}
