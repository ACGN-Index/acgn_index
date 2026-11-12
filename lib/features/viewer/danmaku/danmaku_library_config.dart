import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕库配置持久化在 SharedPreferences；凭证只属于本机，不随规则导出。
final AsyncNotifierProvider<DanmakuLibraryConfigNotifier, DanmakuLibraryConfig>
danmakuLibraryConfigProvider =
    AsyncNotifierProvider<DanmakuLibraryConfigNotifier, DanmakuLibraryConfig>(
      DanmakuLibraryConfigNotifier.new,
    );

class DanmakuLibraryConfigNotifier extends AsyncNotifier<DanmakuLibraryConfig> {
  static const String _baseUrlKey = 'danmaku_library_base_url';
  static const String _appIdKey = 'danmaku_library_app_id';
  static const String _appSecretKey = 'danmaku_library_app_secret';

  @override
  Future<DanmakuLibraryConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    return DanmakuLibraryConfig(
      baseUrl: prefs.getString(_baseUrlKey) ?? DanmakuLibraryConfig.defaultBaseUrl,
      appId: prefs.getString(_appIdKey) ?? '',
      appSecret: prefs.getString(_appSecretKey) ?? '',
    );
  }

  Future<void> save(DanmakuLibraryConfig config) async {
    state = AsyncData<DanmakuLibraryConfig>(config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, config.baseUrl.trim());
    await prefs.setString(_appIdKey, config.appId.trim());
    await prefs.setString(_appSecretKey, config.appSecret.trim());
  }
}
