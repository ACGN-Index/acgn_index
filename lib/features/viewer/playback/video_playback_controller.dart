import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:flutter/widgets.dart';

/// 播放器状态机。UI 只依赖这一份状态，不直接触碰具体播放后端。
enum VideoPlaybackStatus { idle, loading, playing, paused, completed, failed }

@immutable
class VideoPlaybackState {
  const VideoPlaybackState({
    this.status = VideoPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
  });

  final VideoPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool buffering;

  bool get isPlaying => status == VideoPlaybackStatus.playing;
  bool get isLoading => status == VideoPlaybackStatus.loading;
  bool get hasFailed => status == VideoPlaybackStatus.failed;

  VideoPlaybackState copyWith({
    VideoPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? buffering,
  }) => VideoPlaybackState(
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffering: buffering ?? this.buffering,
  );
}

/// 播放后端的抽象：视频画面、播放控制与位置回调。
///
/// 抽出接口后，查看器页面可以在测试里换成假实现，
/// 也方便将来替换 media_kit 之外的后端。
abstract class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackState get state;

  /// 视频画面；由具体后端返回自己的渲染组件。
  Widget buildSurface(BuildContext context);

  Future<void> open(ViewerMedia media);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }
}
