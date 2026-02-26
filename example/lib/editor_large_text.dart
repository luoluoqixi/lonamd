import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lonamd/lonamd.dart';

import 'package:lonamd_exmaple/find.dart';
import 'package:lonamd_exmaple/menu.dart';

class LargeTextEditor extends StatefulWidget {
  const LargeTextEditor({super.key});

  @override
  State<StatefulWidget> createState() => _LargeTextEditorState();
}

class _LargeTextEditorState extends State<LargeTextEditor> {
  final CodeLineEditingController _controller = CodeLineEditingController();

  @override
  void initState() {
    rootBundle.loadString('assets/large.txt').then((value) {
      _controller.text = value;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CodeEditorHelper.createEditor(
      controller: _controller,
      findBuilder: (context, controller, readOnly) =>
          CodeFindPanelView(controller: controller, readOnly: readOnly),
      toolbarController: const ContextMenuControllerImpl(),
      sperator: Container(width: 1, color: Colors.blue),
    );
  }
}
