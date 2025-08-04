import 'package:flutter/material.dart';
import 'package:flutter_blockly_plus/flutter_blockly_plus.dart';

void main() => runApp(const MaterialApp(home: BlocklyDemo()));

class BlocklyDemo extends StatefulWidget {
  const BlocklyDemo({super.key});

  @override
  State<BlocklyDemo> createState() => _BlocklyDemoState();
}

class _BlocklyDemoState extends State<BlocklyDemo> {
  // 3-1) 최소 툴박스(JSON). 필요한 블록만 추가하세요.
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

  // 3-2) 서버/DB에서 받은 "직렬화 JSON"을 가정한 예시(Map 형태).
  // 실제로는 save()로 얻은 JSON을 그대로 저장/전달하세요.
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

  // Blockly 에디터 옵션(툴박스 포함)
  final BlocklyOptions workspaceConfiguration = BlocklyOptions.fromJson({
    "toolbox": toolboxJson,
    "grid": {
      "spacing": 20,
      "length": 3,
      "colour": "#ccc",
      "snap": true,
    },
  });

  // 변경 이벤트에서 현재 상태/코드를 받아볼 수 있습니다.
  void onChange(BlocklyData data) {
    // data.json: 현재 워크스페이스 JSON(직렬화)
    // data.xml:  현재 워크스페이스 XML
    // data.dart/js/python/...: 코드 문자열
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
                // 핵심: initial에 JSON(Map) 혹은 XML(String)을 넣으면 복원됩니다.
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
