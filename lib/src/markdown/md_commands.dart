import 'package:lonamd/lonamd.dart';

/// Toggle inline formatting marks around the current selection.
///
/// If the selection already has the format, removes it.
/// If no text is selected, inserts empty marks and places cursor between them.
void toggleInlineFormat(
  CodeLineEditingController controller,
  String markChars,
) {
  final selection = controller.selection;
  final int markLen = markChars.length;

  if (selection.isSameLine) {
    final lineText = controller.codeLines[selection.startIndex].text;
    final int start = selection.startOffset;
    final int end = selection.endOffset;

    if (selection.isCollapsed) {
      // No selection: check if cursor is inside marks, or insert empty marks
      if (_isInsideMarks(lineText, start, markChars)) {
        // Already inside marks — remove them
        final markStart = start - markLen;
        final markEnd = start + markLen;
        final newText =
            lineText.substring(0, markStart) + lineText.substring(markEnd);
        controller.runRevocableOp(() {
          final lines = controller.codeLines.toList();
          lines[selection.startIndex] = CodeLine(newText);
          controller.value = CodeLineEditingValue(
            codeLines: CodeLines.of(lines),
            selection: CodeLineSelection.collapsed(
              index: selection.startIndex,
              offset: markStart,
            ),
          );
        });
      } else {
        // Insert empty marks: **|**
        final insert = '$markChars$markChars';
        final newText =
            lineText.substring(0, start) + insert + lineText.substring(start);
        controller.runRevocableOp(() {
          final lines = controller.codeLines.toList();
          lines[selection.startIndex] = CodeLine(newText);
          controller.value = CodeLineEditingValue(
            codeLines: CodeLines.of(lines),
            selection: CodeLineSelection.collapsed(
              index: selection.startIndex,
              offset: start + markLen,
            ),
          );
        });
      }
    } else {
      // Has selection — check if it's already formatted
      final selectedText = lineText.substring(start, end);
      if (_hasWrappingMarks(lineText, start, end, markChars)) {
        // Remove marks
        final newText = lineText.substring(0, start - markLen) +
            selectedText +
            lineText.substring(end + markLen);
        controller.runRevocableOp(() {
          final lines = controller.codeLines.toList();
          lines[selection.startIndex] = CodeLine(newText);
          controller.value = CodeLineEditingValue(
            codeLines: CodeLines.of(lines),
            selection: CodeLineSelection(
              baseIndex: selection.startIndex,
              baseOffset: start - markLen,
              extentIndex: selection.startIndex,
              extentOffset: end - markLen,
            ),
          );
        });
      } else {
        // Add marks
        final newText = lineText.substring(0, start) +
            markChars +
            selectedText +
            markChars +
            lineText.substring(end);
        controller.runRevocableOp(() {
          final lines = controller.codeLines.toList();
          lines[selection.startIndex] = CodeLine(newText);
          controller.value = CodeLineEditingValue(
            codeLines: CodeLines.of(lines),
            selection: CodeLineSelection(
              baseIndex: selection.startIndex,
              baseOffset: start + markLen,
              extentIndex: selection.startIndex,
              extentOffset: end + markLen,
            ),
          );
        });
      }
    }
  }
  // Multi-line selection: currently not supported for inline toggle
}

/// Regex patterns for Markdown line prefixes that should auto-continue.
final RegExp _unorderedListRe = RegExp(r'^(\s*)([-+*])\s(.*)$');
final RegExp _orderedListRe = RegExp(r'^(\s*)(\d+)([.)]\s)(.*)$');
final RegExp _taskListRe = RegExp(r'^(\s*)([-+*])\s\[([ xX])\]\s(.*)$');
final RegExp _blockquoteRe = RegExp(r'^(\s*(?:>\s*)+)(.*)$');

/// Handle Enter key with Markdown-aware continuation.
///
/// Returns `true` if the key was handled (Markdown context detected),
/// `false` if the caller should fall through to `applyNewLine()`.
bool handleMarkdownNewLine(CodeLineEditingController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed) return false;

  final lineText = controller.codeLines[selection.startIndex].text;

  // Try task list first (more specific than unordered list)
  final taskMatch = _taskListRe.firstMatch(lineText);
  if (taskMatch != null) {
    final indent = taskMatch.group(1)!;
    final marker = taskMatch.group(2)!;
    final content = taskMatch.group(4)!;
    if (content.isEmpty) {
      // Empty task item → remove prefix
      _clearPrefix(controller, selection.startIndex);
    } else {
      final prefix = '$indent$marker [ ] ';
      _insertContinuation(controller, prefix);
    }
    return true;
  }

  // Try ordered list
  final orderedMatch = _orderedListRe.firstMatch(lineText);
  if (orderedMatch != null) {
    final indent = orderedMatch.group(1)!;
    final num = int.parse(orderedMatch.group(2)!);
    final sep = orderedMatch.group(3)!;
    final content = orderedMatch.group(4)!;
    if (content.isEmpty) {
      _clearPrefix(controller, selection.startIndex);
    } else {
      final prefix = '$indent${num + 1}$sep';
      _insertContinuation(controller, prefix);
    }
    return true;
  }

  // Try unordered list
  final unorderedMatch = _unorderedListRe.firstMatch(lineText);
  if (unorderedMatch != null) {
    final indent = unorderedMatch.group(1)!;
    final marker = unorderedMatch.group(2)!;
    final content = unorderedMatch.group(3)!;
    if (content.isEmpty) {
      _clearPrefix(controller, selection.startIndex);
    } else {
      final prefix = '$indent$marker ';
      _insertContinuation(controller, prefix);
    }
    return true;
  }

  // Try blockquote
  final quoteMatch = _blockquoteRe.firstMatch(lineText);
  if (quoteMatch != null) {
    final prefix = quoteMatch.group(1)!;
    final content = quoteMatch.group(2)!;
    if (content.isEmpty) {
      _clearPrefix(controller, selection.startIndex);
    } else {
      _insertContinuation(controller, prefix);
    }
    return true;
  }

  return false;
}

/// Insert a new line with the given [prefix] at the cursor position.
void _insertContinuation(
  CodeLineEditingController controller,
  String prefix,
) {
  final selection = controller.selection;
  final lineText = controller.codeLines[selection.startIndex].text;
  final before = lineText.substring(0, selection.startOffset);
  final after = lineText.substring(selection.startOffset);

  controller.runRevocableOp(() {
    final lines = controller.codeLines.toList();
    lines[selection.startIndex] = CodeLine(before);
    lines.insert(selection.startIndex + 1, CodeLine(prefix + after));
    controller.value = CodeLineEditingValue(
      codeLines: CodeLines.of(lines),
      selection: CodeLineSelection.collapsed(
        index: selection.startIndex + 1,
        offset: prefix.length,
      ),
    );
  });
}

/// Clear the Markdown prefix from the current line (empty list item → plain line).
void _clearPrefix(CodeLineEditingController controller, int lineIndex) {
  controller.runRevocableOp(() {
    final lines = controller.codeLines.toList();
    lines[lineIndex] = CodeLine('');
    controller.value = CodeLineEditingValue(
      codeLines: CodeLines.of(lines),
      selection: CodeLineSelection.collapsed(index: lineIndex, offset: 0),
    );
  });
}

/// Check if cursor at [offset] is between mark pairs (e.g., **|**).
bool _isInsideMarks(String text, int offset, String marks) {
  final len = marks.length;
  if (offset < len || offset + len > text.length) return false;
  return text.substring(offset - len, offset) == marks &&
      text.substring(offset, offset + len) == marks;
}

/// Check if the range [start, end) is wrapped by marks.
bool _hasWrappingMarks(String text, int start, int end, String marks) {
  final len = marks.length;
  if (start < len || end + len > text.length) return false;
  return text.substring(start - len, start) == marks &&
      text.substring(end, end + len) == marks;
}
