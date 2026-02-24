import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lonamd/lonamd.dart';
import 'package:lonamd/highlight/languages/json.dart';
import 'package:lonamd/highlight/styles/atom-one-light.dart';

import 'package:lonamd_exmaple/find.dart';
import 'package:lonamd_exmaple/menu.dart';

class JsonEditor extends StatefulWidget {
  const JsonEditor({super.key});

  @override
  State<StatefulWidget> createState() => _JsonEditorState();
}

class _JsonEditorState extends State<JsonEditor> {
  final CodeLineEditingController _controller = CodeLineEditingController();

  @override
  void initState() {
    rootBundle.loadString('assets/code.json').then((value) {
      _controller.text = value;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CodeEditor(
      style: CodeEditorStyle(
        codeTheme: CodeHighlightTheme(
            languages: {'json': CodeHighlightThemeMode(mode: langJson)},
            theme: atomOneLightTheme),
      ),
      controller: _controller,
      wordWrap: false,
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
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
      },
      findBuilder: (context, controller, readOnly) =>
          CodeFindPanelView(controller: controller, readOnly: readOnly),
      toolbarController: const ContextMenuControllerImpl(),
      sperator: Container(width: 1, color: Colors.blue),
    );
  }
}
