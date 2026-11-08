import 'package:acgn_index/app/app.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppLogger.init();

  final container = ProviderContainer();
  try {
    await container.read(builtinRuleSeedProvider.future);
  } on Object catch (error, stackTrace) {
    AppLogger.of('bootstrap').severe('内置规则同步失败', error, stackTrace);
  }

  runApp(UncontrolledProviderScope(container: container, child: const AcgnIndexApp()));
}
