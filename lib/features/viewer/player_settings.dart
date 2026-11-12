import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放器级设置；跨页面保留。
@immutable
class PlayerSettings {
  const PlayerSettings({this.showControlsOnPointerMove = true});

  /// 鼠标移动时是否唤出控制栏；触屏语义不受影响。
  final bool showControlsOnPointerMove;

  PlayerSettings copyWith({bool? showControlsOnPointerMove}) => PlayerSettings(
    showControlsOnPointerMove: showControlsOnPointerMove ?? this.showControlsOnPointerMove,
  );
}

final AsyncNotifierProvider<PlayerSettingsNotifier, PlayerSettings> playerSettingsProvider =
    AsyncNotifierProvider<PlayerSettingsNotifier, PlayerSettings>(
      PlayerSettingsNotifier.new,
    );

class PlayerSettingsNotifier extends AsyncNotifier<PlayerSettings> {
  static const String _hoverKey = 'player_show_controls_on_hover';

  @override
  Future<PlayerSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerSettings(showControlsOnPointerMove: prefs.getBool(_hoverKey) ?? true);
  }

  Future<void> setShowControlsOnPointerMove(bool value) async {
    state = AsyncData<PlayerSettings>(
      (state.value ?? const PlayerSettings()).copyWith(showControlsOnPointerMove: value),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hoverKey, value);
  }
}
