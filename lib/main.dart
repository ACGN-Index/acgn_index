import 'package:acgn_index/app/app.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppLogger.init();
  runApp(const ProviderScope(child: AcgnIndexApp()));
}
