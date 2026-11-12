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
    this.playing = false,
  });

  final VideoPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool buffering;

  /// 后端真实的播放状态，与 [status] 解耦。
  ///
  /// 网络抖动时 libmpv 会继续播放并上报错误，[status] 可能被标记成 failed，
  /// 但画面其实还在走。此时暂停按钮必须依然生效，所以不能只看 [status]。
  final bool playing;

  bool get isPlaying => playing;
  bool get isLoading => status == VideoPlaybackStatus.loading;
  bool get hasFailed => status == VideoPlaybackStatus.failed;

  VideoPlaybackState copyWith({
    VideoPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? buffering,
    bool? playing,
  }) => VideoPlaybackState(
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffering: buffering ?? this.buffering,
    playing: playing ?? this.playing,
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
