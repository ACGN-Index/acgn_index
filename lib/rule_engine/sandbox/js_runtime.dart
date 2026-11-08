/// JS 表达式执行器抽象。
///
/// 实现（M1 使用 `flutter_js` / QuickJS）必须满足：
/// * 只能访问 [bindings] 显式注入的值，不暴露 `dart:io`、`dart:ffi` 或宿主对象；
/// * 超过实现配置的时间上限立即中断（默认 `AppConstants.scriptTimeout`），
///   并转换为 `AppException` 抛出，不允许挂起 UI；
/// * 实例可复用，生命周期由调用方负责，用尽后调用 [dispose]。
abstract interface class JsRuntime {
  /// 同步执行 [script]，返回 JSON 可表达的结果。
  ///
  /// [bindings] 目前包含 `value`（前一步结果）与 `ctx`（只读上下文）。
  Object? evaluate(
    String script, {
    Map<String, Object?> bindings = const <String, Object?>{},
  });

  Future<void> dispose();
}

/// 由组合根注入具体实现，便于测试替身与未来更换引擎。
typedef JsRuntimeFactory = JsRuntime Function();
