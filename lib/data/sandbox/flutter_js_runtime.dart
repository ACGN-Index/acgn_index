import 'dart:convert';

import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/sandbox/js_runtime.dart';
import 'package:flutter_js/flutter_js.dart';

/// 基于 QuickJS 的 JS 表达式运行时。
///
/// 运行时懒加载；只注入 `value` 与 `ctx`，不暴露宿主对象。
class FlutterJsRuntime implements JsRuntime {
  FlutterJsRuntime({
    Duration timeout = AppConstants.scriptTimeout,
    JavascriptRuntime Function()? createRuntime,
  }) : _createRuntime = createRuntime ?? (() => QuickJsRuntime2(timeout: timeout.inSeconds));

  final JavascriptRuntime Function() _createRuntime;
  JavascriptRuntime? _runtime;
  bool _disposed = false;

  @override
  Object? evaluate(
    String script, {
    Map<String, Object?> bindings = const <String, Object?>{},
  }) {
    if (_disposed) {
      throw const UnsupportedCapabilityException('JS 运行时已释放');
    }
    final runtime = _runtime ??= _createRuntime();
    final payload = jsonEncode(bindings);
    final code =
        '''
(function () {
  var __bindings = JSON.parse(${jsonEncode(payload)});
  var value = __bindings.value;
  var ctx = __bindings.ctx;
  var __expr = (
$script
  );
  var __result = typeof __expr === 'function' ? __expr(value, ctx) : __expr;
  return JSON.stringify({ value: __result === undefined ? null : __result });
})()
''';
    final result = runtime.evaluate(code);
    if (result.isError) {
      throw RuleFormatException('JS 执行失败：${result.stringResult}');
    }
    final text = result.stringResult;
    if (text == 'undefined' || text == 'null') {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw RuleFormatException('JS 结果不是合法 JSON：${error.message}', cause: error);
    }
    if (decoded is Map<String, Object?> && decoded.containsKey('value')) {
      return decoded['value'];
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _runtime?.dispose();
    _runtime = null;
  }
}
