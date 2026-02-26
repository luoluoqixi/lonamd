import 'package:flutter/material.dart';
import 'package:lonamd/lonamd.dart';

class BasicField extends StatelessWidget {
  const BasicField({super.key});

  @override
  Widget build(BuildContext context) {
    return CodeEditorHelper.createEditor(
      controller: CodeLineEditingController.fromText(
          ('${'Hello LonaMD💐👏 ' * 10}\n') * 100),
    );
  }
}
