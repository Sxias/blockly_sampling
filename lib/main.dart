import 'package:flutter/material.dart';
import 'package:flutter_blockly_plus/flutter_blockly_plus.dart';

void main() => runApp(const MaterialApp(home: BlocklyDemo()));

class BlocklyDemo extends StatefulWidget {
  const BlocklyDemo({super.key});

  @override
  State<BlocklyDemo> createState() => _BlocklyDemoState();
}

class _BlocklyDemoState extends State<BlocklyDemo> {
  // 1) 툴박스: Loops / Math / Variables
  static const toolboxJson = {
    "kind": "categoryToolbox",
    "contents": [
      {
        "kind": "category",
        "name": "Loops",
        "categorystyle": "loop_category",
        "contents": [
          {"kind": "block", "type": "controls_repeat_ext"},
        ],
      },
      {
        "kind": "category",
        "name": "Math",
        "categorystyle": "math_category",
        "contents": [
          {"kind": "block", "type": "math_number"},
          {"kind": "block", "type": "math_arithmetic"},
          {"kind": "block", "type": "math_change"},
        ],
      },
      {"kind": "category", "name": "Variables", "custom": "VARIABLE"},
    ],
  };

  // 2) 직렬화 JSON 예시
  Map<String, dynamic> savedStateJson = {
    "blocks": {
      "languageVersion": 0,
      "blocks": [
        {
          "type": "math_number",
          "id": "n1",
          "x": 40,
          "y": 40,
          "fields": {"NUM": 42},
        },
      ],
    },
  };

  // 3) 핵심: 아래 두 옵션 추가
  //    "horizontalLayout": true, "toolboxPosition": "bottom"
  //    (추가로 move/zoom은 편의용)
  final BlocklyOptions workspaceConfiguration = BlocklyOptions.fromJson({
    "toolbox": toolboxJson,
    "horizontalLayout": true,
    "toolboxPosition": "end",
    "move": {
      "scrollbars": {"horizontal": true, "vertical": true}, // ← 수정 핵심
      "drag": true,
      "wheel": true,
    },
    "zoom": {"controls": true, "wheel": true, "startScale": 1.0, "maxScale": 3, "minScale": 0.3},
    "grid": {"spacing": 20, "length": 3, "colour": "#ccc", "snap": true},
  });

  void onChange(BlocklyData data) {
    debugPrint("onChange(json): ${data.json}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blockly JSON Load Demo')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocklyEditorWidget(
                workspaceConfiguration: workspaceConfiguration,
                initial: savedStateJson,
                onChange: onChange,
                onError: (err) => debugPrint('Blockly error: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
