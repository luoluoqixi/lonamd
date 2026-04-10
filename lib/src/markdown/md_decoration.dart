import 'package:lonamd/lonamd.dart';

/// Test whether the editor selection intersects the document-offset
/// range [from, to).
///
/// Converts line-based [CodeLineSelection] to document-level offsets
/// using [codeLines] and checks for range overlap.
///
/// This is the Dart equivalent of PurrMD's `isSelectRange(state, node)`.
bool isSelectRange(
  CodeLineSelection selection,
  CodeLines codeLines,
  int from,
  int to,
) {
  final selFrom =
      _documentOffset(codeLines, selection.startIndex, selection.startOffset);
  final selTo =
      _documentOffset(codeLines, selection.endIndex, selection.endOffset);
  return from < selTo && to > selFrom;
}

/// Test whether the editor selection intersects a given line index.
///
/// A simpler check for block-level elements that occupy entire lines.
bool isSelectLine(
  CodeLineSelection selection,
  int lineIndex,
) {
  return lineIndex >= selection.startIndex && lineIndex <= selection.endIndex;
}

/// Convert a (lineIndex, offset) pair to a flat document offset.
///
/// Document offset = sum of lengths of all preceding lines (including
/// their newline characters) + offset within the current line.
int _documentOffset(CodeLines codeLines, int lineIndex, int offset) {
  int docOffset = 0;
  final int count = codeLines.length;
  for (int i = 0; i < lineIndex && i < count; i++) {
    docOffset += codeLines[i].text.length + 1; // +1 for newline
  }
  return docOffset + offset;
}
