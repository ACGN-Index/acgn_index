import 'dart:async';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 基于 media_kit（libmpv）的播放后端，Android / Windows / Linux / macOS / iOS 通用。
class MediaKitVideoPlaybackController extends VideoPlaybackController {
  MediaKitVideoPlaybackController() {
    _player = Player();
    _videoController = VideoController(_player);
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.stream.position.listen(_onPositionChanged),
      _player.stream.duration.listen(
        (duration) => _emit(_state.copyWith(duration: duration)),
      ),
      _player.stream.buffering.listen(
        (buffering) => _emit(_state.copyWith(buffering: buffering)),
      ),
      _player.stream.buffer.listen(
        (buffered) => _emit(_state.copyWith(buffered: buffered)),
      ),
      _player.stream.playing.listen(_onPlayingChanged),
      _player.stream.completed.listen(_onCompletedChanged),
      _player.stream.error.listen(_onError),
    ]);
  }

  static final Logger _logger = AppLogger.of('viewer.playback');

  /// 错误之后的观察窗口：窗口内画面仍有推进就当作网络抖动。
  static const Duration _errorGracePeriod = Duration(seconds: 8);

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  VideoPlaybackState _state = const VideoPlaybackState();
  Timer? _errorGraceTimer;
  bool _disposed = false;

  @override
  VideoPlaybackState get state => _state;

  @override
  Widget buildSurface(BuildContext context) => Video(
    controller: _videoController,
    controls: _buildNoControls,
  );

  static Widget _buildNoControls(VideoState state) => const SizedBox.shrink();

  @override
  Future<void> open(ViewerMedia media) async {
    _errorGraceTimer?.cancel();
    _errorGraceTimer = null;
    _emit(const VideoPlaybackState(status: VideoPlaybackStatus.loading));
    try {
      await _player.open(
        Media(media.uri.toString(), httpHeaders: media.hasHeaders ? media.headers : null),
      );
      await _player.play();
    } on Object catch (error, stackTrace) {
      _logger.severe('打开媒体失败: ${AppLogger.redact(media.uri.toString())}', error, stackTrace);
      _emit(_state.copyWith(status: VideoPlaybackStatus.failed));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> togglePlay() async {
    // 以播放器真实状态为准：即使状态已被标记成 failed，
    // 只要后端还在播放，这里也必须暂停，而不是重复调用 play()。
    if (_player.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _disposed = true;
    _errorGraceTimer?.cancel();
    _errorGraceTimer = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  void _onPositionChanged(Duration position) {
    var next = _state.copyWith(position: position);
    if (next.hasFailed && next.playing && position > _state.position) {
      // 判定失败后画面又继续走了，说明只是网络抖动，自动恢复。
      next = next.copyWith(status: VideoPlaybackStatus.playing);
    }
    _emit(next);
  }

  void _onPlayingChanged(bool playing) {
    final current = _state.status;
    if (playing) {
      _emit(
        _state.copyWith(status: VideoPlaybackStatus.playing, playing: true),
      );
      return;
    }
    final nextStatus =
        current == VideoPlaybackStatus.playing || current == VideoPlaybackStatus.paused
        ? VideoPlaybackStatus.paused
        : current;
    _emit(_state.copyWith(status: nextStatus, playing: false));
  }

  void _onCompletedChanged(bool completed) {
    if (completed) {
      _errorGraceTimer?.cancel();
      _errorGraceTimer = null;
      _emit(
        _state.copyWith(status: VideoPlaybackStatus.completed, playing: false),
      );
    }
  }

  void _onError(String message) {
    _logger.warning('播放错误: ${AppLogger.redact(message)}');
    // libmpv 在网络抖动、某个分片暂时取不到时也会上报 error 日志，
    // 此时画面往往还在继续播放。先观察一小段时间：
    // 播放位置仍有推进就当作可恢复错误忽略，确实停住了才判定失败。
    _armErrorGraceTimer();
  }

  void _armErrorGraceTimer() {
    if (_errorGraceTimer != null || _disposed) {
      return;
    }
    final anchor = _player.state.position;
    _errorGraceTimer = Timer(_errorGracePeriod, () {
      _errorGraceTimer = null;
      if (_disposed) {
        return;
      }
      if (_player.state.position > anchor) {
        return;
      }
      final status = _state.status;
      if (status != VideoPlaybackStatus.loading && status != VideoPlaybackStatus.playing) {
        // 用户主动暂停或已播完，不要因为旧错误把界面切到失败态。
        return;
      }
      _logger.warning('错误后画面无进展，判定播放失败');
      _emit(_state.copyWith(status: VideoPlaybackStatus.failed));
    });
  }

  void _emit(VideoPlaybackState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
