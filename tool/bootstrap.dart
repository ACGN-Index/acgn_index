import 'dart:io';

/// 一键准备本地开发环境：拉依赖 → 生成 l10n → 运行代码生成。
///
/// 生成物（`*.g.dart`、`lib/l10n/generated/`）不入库，克隆或改动生成源后都要执行：
/// `dart run tool/bootstrap.dart`
Future<void> main() async {
  const steps = <_BootstrapStep>[
    _BootstrapStep('flutter pub get', 'flutter', ['pub', 'get']),
    _BootstrapStep('flutter gen-l10n', 'flutter', ['gen-l10n']),
    _BootstrapStep('dart run build_runner build', 'dart', ['run', 'build_runner', 'build']),
    // 生成物使用 dart_style 默认行宽，需按项目设置再格式化一次，
    // 否则 `dart format --set-exit-if-changed` 会因生成文件报错。
    _BootstrapStep('dart format (generated)', 'dart', ['format', 'lib/data', 'lib/l10n']),
  ];

  for (final step in steps) {
    stdout.writeln('\n> ${step.label}');
    final process = await Process.start(
      step.executable,
      step.arguments,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      stderr.writeln('\n✗ ${step.label} 失败，退出码 $exitCode');
      exit(exitCode);
    }
  }

  stdout.writeln('\n✔ 环境准备完成');
}

class _BootstrapStep {
  const _BootstrapStep(this.label, this.executable, this.arguments);

  final String label;
  final String executable;
  final List<String> arguments;
}
