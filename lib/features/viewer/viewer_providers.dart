import 'package:acgn_index/features/viewer/playback/media_kit_video_playback_controller.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 播放后端工厂。测试里覆盖成假实现，页面因此不直接依赖 media_kit。
final Provider<VideoPlaybackController Function()> videoPlaybackControllerFactoryProvider =
    Provider<VideoPlaybackController Function()>((ref) => MediaKitVideoPlaybackController.new);
