import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lonamd/lonamd.dart';

import 'package:lonamd_exmaple/find.dart';
import 'package:lonamd_exmaple/menu.dart';

class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({super.key});

  @override
  State<StatefulWidget> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final CodeLineEditingController _controller = CodeLineEditingController();

  @override
  void initState() {
    rootBundle.loadString('assets/markdown.md').then((value) {
      _controller.text = value;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CodeEditorHelper.createMarkdownEditor(
      mdConfig: MarkdownEditorConfig(
        codeTheme: mdHighlightTheme(),
      ),
      controller: _controller,
      wysiwygConfig: const MdWysiwygConfig(),
      findBuilder: (context, controller, readOnly) =>
          CodeFindPanelView(controller: controller, readOnly: readOnly),
      toolbarController: const ContextMenuControllerImpl(),
      sperator: Container(width: 1, color: Colors.blue),
    );
  }
}
