import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_blockly_plus/flutter_blockly_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const MaterialApp(home: BlocklyShell()));

class BlocklyShell extends StatefulWidget {
  const BlocklyShell({super.key});

  @override
  State<BlocklyShell> createState() => _BlocklyShellState();
}

class _BlocklyShellState extends State<BlocklyShell> {
  double _terminalHeight = 200;
  final _log = <String>[];

  BlocklyEditor? editor;
  late final Future<void> _editorReady;

  // 툴박스
  static const toolboxJson = {
    "kind": "categoryToolbox",
    "contents": [
      {
        "kind": "category",
        "name": "Logic",
        "categorystyle": "logic_category",
        "contents": [
          {"kind": "block", "type": "controls_if"},
          {"kind": "block", "type": "logic_compare"},
          {"kind": "block", "type": "logic_operation"},
          {"kind": "block", "type": "logic_boolean"},
        ],
      },
      {
        "kind": "category",
        "name": "Loops",
        "categorystyle": "loop_category",
        "contents": [
          {"kind": "block", "type": "controls_repeat_ext"},
          {"kind": "block", "type": "controls_whileUntil"},
          {
            "kind": "block",
            "type": "controls_for",
            "inputs": {
              "FROM": {
                "shadow": {
                  "type": "math_number",
                  "fields": {"NUM": 1},
                },
              },
              "TO": {
                "shadow": {
                  "type": "math_number",
                  "fields": {"NUM": 10},
                },
              },
              "BY": {
                "shadow": {
                  "type": "math_number",
                  "fields": {"NUM": 1},
                },
              },
            },
          },
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
      {
        "kind": "category",
        "name": "Text",
        "categorystyle": "text_category",
        "contents": [
          {
            "kind": "block",
            "type": "text",
            "fields": {"TEXT": "Hello"},
          },
          {"kind": "block", "type": "text_print"},
        ],
      },
      {"kind": "category", "name": "Variables", "custom": "VARIABLE"},
    ],
  };

  // 초기 상태(예시)
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
    "horizontalLayout": false,
    "toolboxPosition": "start",
    "move": {
      "scrollbars": {"horizontal": true, "vertical": true},
      "drag": true,
      "wheel": true,
    },
    "zoom": {"controls": true, "wheel": true, "startScale": 1.0, "maxScale": 2.5, "minScale": 0.3},
    "grid": {"spacing": 20, "length": 3, "colour": "#1f2937", "snap": true},
  });

  @override
  void initState() {
    super.initState();
    _editorReady = _initEditor();
  }

  Future<void> _initEditor() async {
    try {
      // 1) 애드온 로드
      final skinJs = await rootBundle.loadString('assets/blockly/toolbox_skin.js');
      final javaGenJs = await rootBundle.loadString('assets/blockly/java_generator.js');
      _log.add('[BOOT] addons loaded: skin=${skinJs.length}, javaGen=${javaGenJs.length}');

      // 2) 에디터 생성
      editor = BlocklyEditor(
        workspaceConfiguration: workspaceConfiguration,
        initial: savedStateJson,
        addons: [skinJs, javaGenJs],
        onError: (e) {
          _log.add('[ERR] $e');
          setState(() {});
        },
        onChange: (_) {},
        onInject: (_) => _log.add('[INJECT] called'),
      );

      // 3) init 전에 WebView 컨트롤러 세팅
      final ctrl = editor!.blocklyController;
      await ctrl.setJavaScriptMode(JavaScriptMode.unrestricted);
      await ctrl.setBackgroundColor(const Color(0x00000000));

      // ★ JS 채널 등록: window.JavaOut.postMessage(code) 수신
      await ctrl.addJavaScriptChannel(
        'JavaOut',
        onMessageReceived: (JavaScriptMessage msg) {
          final code = msg.message;
          _log.add('[JAVA]\n$code'); // 앱 내 터미널
          debugPrint('[JAVA from channel]\n$code'); // Flutter 콘솔
          setState(() {});
        },
      );

      await ctrl.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _log.add('[WEB] onPageStarted: $url');
            setState(() {});
          },
          onPageFinished: (url) async {
            _log.add('[WEB] onPageFinished: $url');
            _log.add(
              '[WEB] ready=${await _ret('document.readyState')}, Blockly=${await _ret('typeof window.Blockly')}, workspace=${await _ret('(window.Blockly&&Blockly.getMainWorkspace)? "ok":"no"')}, JavaGen=${await _ret('(window.__JAVA_GEN_OK__===true)?"ok":"no"')}',
            );
            setState(() {});
          },
          onWebResourceError: (err) {
            _log.add('[WEB-ERR] $err');
            setState(() {});
          },
        ),
      );

      // 4) 초기화 + HTML 로드
      editor!.init();
      _log.add('[BOOT] editor.init() called (after JS+delegate set)');

      final html = editor!.htmlRender();
      _log.add('[BOOT] htmlRender length=${html.length}');
      await ctrl.loadHtmlString(html);
      _log.add('[BOOT] loadHtmlString called');
    } catch (e) {
      _log.add('[BOOT-ERR] $e');
      setState(() {});
    }
  }

  Future<String> _ret(String js) async {
    try {
      final raw = await editor!.blocklyController.runJavaScriptReturningResult(js);
      if (raw is String && raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
        return raw.substring(1, raw.length - 1);
      }
      return raw?.toString() ?? 'null';
    } catch (e) {
      _log.add('[JS-ERR] $e');
      setState(() {});
      return 'ERR';
    }
  }

  // ▶ 실행: JS에서 JavaOut 채널로 push
  Future<void> _runAndPushViaChannel() async {
    final ctrl = editor?.blocklyController;
    if (ctrl == null) {
      _log.add('[RUN-ERR] controller=null');
      setState(() {});
      return;
    }
    try {
      await ctrl.runJavaScriptReturningResult('window.BlocklyJavaSend()');
      _log.add(
        '[RUN] ready=${await _ret('document.readyState')}, Blockly=${await _ret('typeof window.Blockly')}, ws=${await _ret('(window.Blockly&&Blockly.getMainWorkspace)? "ok":"no"')}, JavaGen=${await _ret('(window.__JAVA_GEN_OK__===true)?"ok":"no"')}',
      );
    } catch (e) {
      _log.add('[RUN-ERR] $e');
      setState(() {});
    }
    setState(() {});
  }

  // 🐞 Ping (요약)
  Future<void> _ping() async {
    final ctrl = editor?.blocklyController;
    if (ctrl == null) return;
    try {
      final genState = await ctrl.runJavaScriptReturningResult(
        '(function(){return (window.__JAVA_GEN_OK__===true)?"ok":(window.__installJavaGenerator?(__installJavaGenerator()?"installed":"fail"):"no_fn");})()',
      );
      final snapJs = r'''
        (function(){
          try{
            var ws = (window.Blockly && Blockly.getMainWorkspace) ? Blockly.getMainWorkspace() : null;
            var res = {
              ready: (typeof document!=='undefined')?document.readyState:null,
              hasBlockly: (typeof window.Blockly),
              ver: (window.Blockly && (Blockly.VERSION || Blockly.version || null)) || null,
              ws: !!ws,
              blocks: ws && ws.getAllBlocks ? ws.getAllBlocks(false).length : null,
              javaGenOk: !!window.__JAVA_GEN_OK__,
              hasFinish: !!(window.Blockly && Blockly.Java && Blockly.Java.finish),
              varGet: !!(window.Blockly && Blockly.Java && (typeof Blockly.Java['variables_get']==='function')),
              varSet: !!(window.Blockly && Blockly.Java && (typeof Blockly.Java['variables_set']==='function')),
              mathChange: !!(window.Blockly && Blockly.Java && (typeof Blockly.Java['math_change']==='function'))
            };
            try{
              var keys=[];
              if (window.Blockly && Blockly.Java){
                for (var k in Blockly.Java){
                  if (typeof Blockly.Java[k]==='function' && !/^[A-Z_]+$/.test(k)) keys.push(k);
                }
              }
              res.handlers = keys.sort();
            }catch(e){}
            return JSON.stringify(res);
          }catch(e){return JSON.stringify({fatal:String(e)})}
        })();
      ''';
      final raw = await ctrl.runJavaScriptReturningResult(snapJs);
      final s = raw?.toString() ?? '{}';
      final jsonStr = (s.startsWith('"') && s.endsWith('"')) ? s.substring(1, s.length - 1) : s;
      final Map<String, dynamic> d = jsonDecode(jsonStr);
      _log.add("[DBG] genState=$genState");
      _log.add(
        "[DBG] ready=${d['ready']}, Blockly=${d['hasBlockly']}, ver=${d['ver']}, ws=${d['ws']}, blocks=${d['blocks']}",
      );
      _log.add(
        "[DBG] javaGenOk=${d['javaGenOk']}, hasFinish=${d['hasFinish']}, varGet=${d['varGet']}, varSet=${d['varSet']}, mathChange=${d['mathChange']}",
      );
      _log.add("[DBG] handlers=${d['handlers']}");
    } catch (e) {
      _log.add('[DBG-ERR] $e');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const splitterHeight = 8.0;
    const minWorkspaceHeight = 160.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockly + Terminal Layout (Channel)'),
        actions: [
          IconButton(icon: const Icon(Icons.bug_report), onPressed: _ping),
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: _runAndPushViaChannel),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _editorReady,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done || editor == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight;
                final w = c.maxWidth;
                final maxTerminal = (h - minWorkspaceHeight - splitterHeight).clamp(0.0, h);
                final terminalHeight = _terminalHeight.clamp(120.0, maxTerminal).toDouble();
                final workspaceHeight = (h - terminalHeight - splitterHeight).toDouble();

                return Column(
                  children: [
                    SizedBox(
                      height: workspaceHeight,
                      width: w,
                      child: WebViewWidget(controller: editor!.blocklyController),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) {
                        setState(() => _terminalHeight = (_terminalHeight - d.delta.dy));
                      },
                      child: Container(
                        color: Colors.grey.shade400,
                        height: splitterHeight,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Container(width: 60, height: 3, color: Colors.grey.shade700),
                      ),
                    ),
                    Container(
                      height: terminalHeight,
                      width: double.infinity,
                      color: const Color(0xFF111827),
                      child: Padding(
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
