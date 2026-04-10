# LonaMD

Flutter Markdown Editor Based on [Re-Editor](https://github.com/reqable/re-editor), Providing a Smooth Editing Experience Similar to Obsidian.

In development...

[中文版本](./README_CN.md)

## Features

- **WYSIWYG-style editing**: Inline marks (`**`, `*`, `` ` ``, `~~`, `==`) and link syntax are hidden when the cursor is not on the same line, revealing clean formatted text. Marks reappear when you navigate to the line. Controlled via `MdWysiwygConfig`.
- **Format toggle shortcuts**: Ctrl+B (Bold), Ctrl+I (Italic), Ctrl+Shift+D (Strikethrough), Ctrl+Shift+H (Highlight).
- **Auto-continue lists**: Press Enter on a list item, task list, ordered list, or blockquote to automatically continue the prefix. Press Enter on an empty item to exit the list.
- **GFM support**: Strikethrough, highlight, tables, task lists.
- **Markdown syntax highlighting**: Full AST-based highlighting with customizable themes.

## Usage

```dart
CodeEditorHelper.createMarkdownEditor(
  controller: controller,
  wysiwygConfig: const MdWysiwygConfig(), // Enable WYSIWYG mode
);
```

## License

MIT License
