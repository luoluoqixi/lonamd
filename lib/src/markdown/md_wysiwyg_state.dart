import 'package:lonamd/lonamd.dart';

import 'md_wysiwyg_config.dart';

/// Mutable state that the decoration system reads to decide whether
/// to hide or show Markdown formatting marks.
///
/// Updated by _CodeEditable on selection/focus changes, consumed
/// by _CodeHighlighter during the TextSpan build phase.
class MdWysiwygState {
  /// Current selection in the editor.
  CodeLineSelection selection;

  /// Whether the editor currently has focus.
  bool hasFocus;

  /// The WYSIWYG configuration.
  MdWysiwygConfig config;

  /// The line index the cursor was on before the last change.
  /// Used to invalidate only the affected lines.
  int _previousLineIndex;

  MdWysiwygState({
    this.selection = const CodeLineSelection.zero(),
    this.hasFocus = false,
    this.config = const MdWysiwygConfig(),
  }) : _previousLineIndex = selection.startIndex;

  /// Update selection and return the set of line indices that need
  /// their paragraph cache invalidated.
  Set<int> updateSelection(CodeLineSelection newSelection) {
    final Set<int> affected = {};
    // Add lines that were previously in the selection range
    for (int i = selection.startIndex; i <= selection.endIndex; i++) {
      affected.add(i);
    }
    // Add lines in the new selection range
    for (int i = newSelection.startIndex; i <= newSelection.endIndex; i++) {
      affected.add(i);
    }
    _previousLineIndex = selection.startIndex;
    selection = newSelection;
    return affected;
  }

  /// Update focus and return whether the decoration needs a full refresh.
  bool updateFocus(bool newHasFocus) {
    if (hasFocus == newHasFocus) return false;
    hasFocus = newHasFocus;
    return true; // Full refresh needed on focus change
  }
}
