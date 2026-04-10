part of lonamd;

class AutocompleteConfig {
  final CodeAutocompleteWidgetBuilder viewBuilder;
  final CodeAutocompletePromptsBuilder promptsBuilder;

  const AutocompleteConfig({
    required this.viewBuilder,
    required this.promptsBuilder,
  });
}

class MarkdownEditorConfig {
  /// The code syntax highlighting rules and styles.
  final CodeHighlightTheme? codeTheme;

  const MarkdownEditorConfig({required this.codeTheme});
}

class CodeEditorHelper {
  static Widget _defaultIndicatorBuilder(
    BuildContext context,
    CodeLineEditingController editingController,
    CodeChunkController chunkController,
    CodeIndicatorValueNotifier notifier,
  ) {
    return Row(
      children: [
        DefaultCodeLineNumber(
          controller: editingController,
          notifier: notifier,
        ),
        DefaultCodeChunkIndicator(
            width: 20, controller: chunkController, notifier: notifier)
      ],
    );
  }

  static Widget createEditor({
    final AutocompleteConfig? autocomplete,
    final CodeLineEditingController? controller,
    final CodeScrollController? scrollController,
    final CodeFindController? findController,
    final SelectionToolbarController? toolbarController,
    final ValueChanged<CodeLineEditingValue>? onChanged,
    final CodeEditorStyle? style,
    final String? hint,
    final EdgeInsetsGeometry? padding,
    final EdgeInsetsGeometry? margin,
    final CodeIndicatorBuilder? indicatorBuilder,
    final CodeScrollbarBuilder? scrollbarBuilder,
    final double? verticalScrollbarWidth,
    final double? horizontalScrollbarHeight,
    final CodeFindBuilder? findBuilder,
    final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder,
    final Map<Type, Action<Intent>>? shortcutOverrideActions,
    final Widget? sperator,
    final Border? border,
    final BorderRadius? borderRadius,
    final Clip clipBehavior = Clip.none,
    final bool? readOnly,
    final bool? showCursorWhenReadOnly,
    final bool? wordWrap,
    final bool? autocompleteSymbols,
    final bool? autofocus,
    final FocusNode? focusNode,
    final int? maxLengthSingleLineRendering,
    final CodeChunkAnalyzer? chunkAnalyzer,
    final CodeCommentFormatter? commentFormatter,
    final MdWysiwygConfig? wysiwygConfig,
  }) {
    final child = CodeEditor(
      controller: controller,
      scrollController: scrollController,
      findController: findController,
      toolbarController: toolbarController,
      onChanged: onChanged,
      style: style,
      hint: hint,
      padding: padding,
      margin: margin,
      indicatorBuilder: indicatorBuilder ?? _defaultIndicatorBuilder,
      scrollbarBuilder: scrollbarBuilder,
      verticalScrollbarWidth: verticalScrollbarWidth,
      horizontalScrollbarHeight: horizontalScrollbarHeight,
      findBuilder: findBuilder,
      shortcutsActivatorsBuilder: shortcutsActivatorsBuilder,
      shortcutOverrideActions: shortcutOverrideActions,
      sperator: sperator,
      border: border,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      readOnly: readOnly,
      showCursorWhenReadOnly: showCursorWhenReadOnly,
      wordWrap: wordWrap ?? false,
      autocompleteSymbols: autocompleteSymbols,
      autofocus: autofocus,
      focusNode: focusNode,
      maxLengthSingleLineRendering: maxLengthSingleLineRendering,
      chunkAnalyzer: chunkAnalyzer,
      commentFormatter: commentFormatter,
      wysiwygConfig: wysiwygConfig,
    );
    if (autocomplete != null) {
      return CodeAutocomplete(
        viewBuilder: autocomplete.viewBuilder,
        promptsBuilder: autocomplete.promptsBuilder,
        child: child,
      );
    }
    return child;
  }

  static Widget createMarkdownEditor({
    final MarkdownEditorConfig? mdConfig,
    final AutocompleteConfig? autocomplete,
    final CodeLineEditingController? controller,
    final CodeScrollController? scrollController,
    final CodeFindController? findController,
    final SelectionToolbarController? toolbarController,
    final ValueChanged<CodeLineEditingValue>? onChanged,
    final CodeEditorStyle? style,
    final String? hint,
    final EdgeInsetsGeometry? padding,
    final EdgeInsetsGeometry? margin,
    final CodeIndicatorBuilder? indicatorBuilder,
    final CodeScrollbarBuilder? scrollbarBuilder,
    final double? verticalScrollbarWidth,
    final double? horizontalScrollbarHeight,
    final CodeFindBuilder? findBuilder,
    final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder,
    final Map<Type, Action<Intent>>? shortcutOverrideActions,
    final Widget? sperator,
    final Border? border,
    final BorderRadius? borderRadius,
    final Clip clipBehavior = Clip.none,
    final bool? readOnly,
    final bool? showCursorWhenReadOnly,
    final bool? wordWrap,
    final bool? autocompleteSymbols,
    final bool? autofocus,
    final FocusNode? focusNode,
    final int? maxLengthSingleLineRendering,
    final CodeChunkAnalyzer? chunkAnalyzer,
    final CodeCommentFormatter? commentFormatter,
    final MdWysiwygConfig? wysiwygConfig,
  }) {
    final markdownStyle = style ??
        CodeEditorStyle(
          codeTheme: mdConfig?.codeTheme,
        );
    return createEditor(
      autocomplete: autocomplete,
      controller: controller,
      scrollController: scrollController,
      findController: findController,
      toolbarController: toolbarController,
      onChanged: onChanged,
      style: markdownStyle,
      hint: hint,
      padding: padding,
      margin: margin,
      indicatorBuilder: indicatorBuilder,
      scrollbarBuilder: scrollbarBuilder,
      verticalScrollbarWidth: verticalScrollbarWidth,
      horizontalScrollbarHeight: horizontalScrollbarHeight,
      findBuilder: findBuilder,
      shortcutsActivatorsBuilder: shortcutsActivatorsBuilder,
      shortcutOverrideActions: shortcutOverrideActions,
      sperator: sperator,
      border: border,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      readOnly: readOnly,
      showCursorWhenReadOnly: showCursorWhenReadOnly,
      wordWrap: wordWrap ?? true,
      autocompleteSymbols: autocompleteSymbols,
      autofocus: autofocus,
      focusNode: focusNode,
      maxLengthSingleLineRendering: maxLengthSingleLineRendering,
      chunkAnalyzer: chunkAnalyzer,
      commentFormatter: commentFormatter,
      wysiwygConfig: wysiwygConfig ?? const MdWysiwygConfig(),
    );
  }
}
