import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/core/errors/app_exception.dart';

/// JS 表达式执行器抽象。
///
/// 实现（M1 使用 `flutter_js` / QuickJS）必须满足：
/// * 只能访问 [bindings] 显式注入的值，不暴露 `dart:io`、`dart:ffi` 或宿主对象；
/// * 注入的 `http` 仅允许访问规则包声明的 host；
/// * 超过 `timeout` 立即中断，并转换为 [AppException] 抛出，不允许挂起 UI；
/// * 实例可复用，生命周期由调用方负责，用尽后调用 [dispose]。
abstract interface class JsRuntime {
  Future<Object?> evaluate(
    String script, {
    Map<String, Object?> bindings = const <String, Object?>{},
    Duration timeout = AppConstants.scriptTimeout,
  });

  Future<void> dispose();
}

/// 由组合根注入具体实现，便于测试替身与未来更换引擎。
typedef JsRuntimeFactory = JsRuntime Function();
