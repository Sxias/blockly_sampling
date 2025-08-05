import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_blockly_plus/flutter_blockly_plus.dart';

void main() => runApp(const MaterialApp(home: BlocklyShell()));

class BlocklyShell extends StatefulWidget {
  const BlocklyShell({super.key});

  @override
  State<BlocklyShell> createState() => _BlocklyShellState();
}

class _BlocklyShellState extends State<BlocklyShell> {
  // 터미널 높이(드래그로 조절)
  double _terminalHeight = 200;

  // 기본 툴박스(좌측)
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

  // 워크스페이스 초기 JSON(예시)
  final Map<String, dynamic> savedStateJson = {
    "blocks": {
      "languageVersion": 0,
      "blocks": [
        {
          "type": "math_number",
          "x": 40,
          "y": 40,
          "fields": {"NUM": 42},
        },
      ],
    },
  };

  late final BlocklyOptions workspaceConfiguration = BlocklyOptions.fromJson({
    "toolbox": toolboxJson,
    // 수직 툴박스 + 좌측 배치
    "horizontalLayout": false,
    "toolboxPosition": "start", // start=좌/상, end=우/하
    "move": {
      "scrollbars": {"horizontal": true, "vertical": true},
      "drag": true,
      "wheel": true,
    },
    "zoom": {"controls": true, "wheel": true, "startScale": 1.0, "maxScale": 2.5, "minScale": 0.3},
    "grid": {"spacing": 20, "length": 3, "colour": "#1f2937", "snap": true},
  });

  Future<List<String>> _loadAddons() async {
    final skin = await rootBundle.loadString('assets/blockly/toolbox_skin.js');
    // final dialog = await rootBundle.loadString('assets/blockly/dialog_override.js');
    return [skin /*, dialog*/];
  }

  final _log = <String>[];

  void _onChange(BlocklyData data) {
    // 필요 시 코드/JSON을 터미널에 출력
    if (data.js != null) _log.add('[JS] ${data.js}');
    if (data.json != null) _log.add('[JSON] ${data.json}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const splitterHeight = 8.0; // 드래그 핸들 높이
    const minWorkspaceHeight = 160.0; // 워크스페이스 최소 보장 높이

    return Scaffold(
      appBar: AppBar(title: const Text('Blockly + Terminal Layout')),
      body: SafeArea(
        // 하단 제스처/네비게이션바 인셋 반영
        child: FutureBuilder<List<String>>(
          future: _loadAddons(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return LayoutBuilder(
              builder: (context, c) {
                final double h = c.maxHeight;
                final double w = c.maxWidth;

                // 터미널 높이 최대값: 전체 - 워크스페이스 최소 - 스플리터
                final double maxTerminal = (h - minWorkspaceHeight - splitterHeight).clamp(0.0, h);
                // NOTE: clamp의 반환형이 num → double로 변환
                final double terminalHeight = _terminalHeight.clamp(120.0, maxTerminal).toDouble();

                // 상단 워크스페이스 실제 높이
                final double workspaceHeight = (h - terminalHeight - splitterHeight).clamp(0.0, h).toDouble();

                return Column(
                  children: [
                    // 상단: 블록 워크스페이스(툴박스는 WebView 내부 좌측)
                    SizedBox(
                      height: workspaceHeight,
                      width: w,
                      child: BlocklyEditorWidget(
                        workspaceConfiguration: workspaceConfiguration,
                        initial: savedStateJson,
                        addons: snap.data!,
                        // CSS/JS 주입
                        debug: false,
                        onChange: _onChange,
                        onError: (err) => _log.add('[ERR] $err'),
                      ),
                    ),

                    // 드래그 핸들(스플리터)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) {
                        setState(() {
                          _terminalHeight = (_terminalHeight - d.delta.dy);
                        });
                      },
                      child: Container(
                        color: Colors.grey.shade400,
                        height: splitterHeight,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Container(
                          width: 60,
                          height: 3,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    // 하단: 터미널
                    Container(
                      height: terminalHeight,
                      width: double.infinity,
                      color: const Color(0xFF111827),
                      child: Padding(
                        // 하단 시스템 인셋만 추가 보정
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 12,
                          bottom: 12 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _log.length,
                          itemBuilder: (_, i) => Text(
                            _log[_log.length - 1 - i],
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
