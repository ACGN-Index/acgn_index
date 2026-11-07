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
      _player.stream.position.listen(
        (position) => _emit(_state.copyWith(position: position)),
      ),
      _player.stream.duration.listen(
        (duration) => _emit(_state.copyWith(duration: duration)),
      ),
      _player.stream.buffering.listen(
        (buffering) => _emit(_state.copyWith(buffering: buffering)),
      ),
      _player.stream.playing.listen(_onPlayingChanged),
      _player.stream.completed.listen(_onCompletedChanged),
      _player.stream.error.listen(_onError),
    ]);
  }

  static final Logger _logger = AppLogger.of('viewer.playback');

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  VideoPlaybackState _state = const VideoPlaybackState();
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
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  void _onPlayingChanged(bool playing) {
    final current = _state.status;
    if (playing) {
      _emit(_state.copyWith(status: VideoPlaybackStatus.playing));
      return;
    }
    if (current == VideoPlaybackStatus.playing || current == VideoPlaybackStatus.paused) {
      _emit(_state.copyWith(status: VideoPlaybackStatus.paused));
    }
  }

  void _onCompletedChanged(bool completed) {
    if (completed) {
      _emit(_state.copyWith(status: VideoPlaybackStatus.completed));
    }
  }

  void _onError(String message) {
    _logger.warning('播放错误: ${AppLogger.redact(message)}');
    _emit(_state.copyWith(status: VideoPlaybackStatus.failed));
  }

  void _emit(VideoPlaybackState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
