import 'dart:async';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_engine.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_overlay.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings_sheet.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:acgn_index/features/viewer/viewer_providers.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_message_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

/// 视频查看器：播放器 + 弹幕 + 选集，布局参考 B 站播放页。
class VideoViewerPage extends ConsumerStatefulWidget {
  const VideoViewerPage({this.content, super.key});

  final VideoViewerContent? content;

  @override
  ConsumerState<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends ConsumerState<VideoViewerPage> {
  static final Logger _logger = AppLogger.of('viewer.video');
  static const Duration _controlsTimeout = Duration(seconds: 3);

  VideoPlaybackController? _playback;
  DanmakuEngine? _engine;
  TextEditingController? _danmakuInput;
  FocusNode? _danmakuFocus;
  Timer? _hideTimer;
  DanmakuSettings _danmakuSettings = const DanmakuSettings();
  int _episodeIndex = 0;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _isScrubbing = false;
  bool _wasPlaying = false;
  double _scrubValue = 0;

  VideoViewerContent? get _content => widget.content;

  VideoEpisode? get _episode {
    final content = _content;
    if (content == null || content.episodes.isEmpty) {
      return null;
    }
    return content.episodes[_episodeIndex];
  }

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    if (content == null || content.episodes.isEmpty) {
      return;
    }
    _episodeIndex = content.safeInitialEpisodeIndex;
    _danmakuInput = TextEditingController();
    _danmakuFocus = FocusNode();
    final playback = ref.read(videoPlaybackControllerFactoryProvider)();
    _playback = playback..addListener(_handlePlaybackChanged);
    final episode = content.episodes[_episodeIndex];
    _engine = DanmakuEngine(comments: episode.danmaku);
    unawaited(playback.open(episode.media));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playback?.removeListener(_handlePlaybackChanged);
    _playback?.dispose();
    _engine?.dispose();
    _danmakuInput?.dispose();
    _danmakuFocus?.dispose();
    if (_isFullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final playback = _playback;
    final engine = _engine;
    if (content == null || content.episodes.isEmpty || playback == null || engine == null) {
      return ViewerMessagePage(
        icon: Icons.movie_filter_outlined,
        title: l10n.viewerContentMissingTitle,
        message: l10n.viewerContentMissingBody,
      );
    }

    final state = playback.state;
    final episode = content.episodes[_episodeIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: Colors.black, child: playback.buildSurface(context)),
          if (_danmakuSettings.enabled)
            DanmakuOverlay(
              engine: engine,
              settings: _danmakuSettings,
              position: state.position,
              playing: state.isPlaying,
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTap: _togglePlay,
            ),
          ),
          if (state.isLoading || (state.buffering && state.isPlaying))
            const Center(child: CircularProgressIndicator()),
          if (state.hasFailed)
            _PlaybackErrorView(
              message: l10n.viewerPlaybackError,
              retryLabel: l10n.viewerRetry,
              onRetry: _retry,
            ),
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildChrome(context, l10n, state, episode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChrome(
    BuildContext context,
    AppLocalizations l10n,
    VideoPlaybackState state,
    VideoEpisode episode,
  ) {
    return Column(
      children: <Widget>[
        _buildTopBar(l10n, episode),
        Expanded(
          child: Center(
            child: state.hasFailed || state.isLoading
                ? const SizedBox.shrink()
                : IconButton.filledTonal(
                    onPressed: _togglePlay,
                    iconSize: 48,
                    tooltip: state.isPlaying ? l10n.viewerPause : l10n.viewerPlay,
                    icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
          ),
        ),
        _buildBottomBar(l10n, state),
      ],
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, VideoEpisode episode) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _handleBack,
            tooltip: l10n.viewerBack,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _content?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleFullscreen,
            tooltip: _isFullscreen ? l10n.viewerExitFullscreen : l10n.viewerFullscreen,
            color: Colors.white,
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, VideoPlaybackState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildProgressBar(state),
          Row(
            children: <Widget>[
              IconButton(
                onPressed: _togglePlay,
                tooltip: state.isPlaying ? l10n.viewerPause : l10n.viewerPlay,
                color: Colors.white,
                icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              Text(
                '${_formatDuration(_isScrubbing ? Duration(milliseconds: _scrubValue.round()) : state.position)}'
                ' / ${_formatDuration(state.duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: _toggleDanmaku,
                tooltip: l10n.viewerDanmaku,
                color: _danmakuSettings.enabled ? Colors.white : Colors.white38,
                icon: Icon(
                  _danmakuSettings.enabled ? Icons.subtitles : Icons.subtitles_off,
                ),
              ),
              IconButton(
                onPressed: _openDanmakuSettings,
                tooltip: l10n.viewerDanmakuSettings,
                color: Colors.white,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                onPressed: _openEpisodes,
                tooltip: l10n.viewerEpisodes,
                color: Colors.white,
                icon: const Icon(Icons.playlist_play),
              ),
              IconButton(
                onPressed: _toggleFullscreen,
                tooltip: _isFullscreen ? l10n.viewerExitFullscreen : l10n.viewerFullscreen,
                color: Colors.white,
                icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
              ),
            ],
          ),
          if (_danmakuSettings.enabled) _buildDanmakuComposer(l10n),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlaybackState state) {
    final durationMs = state.duration.inMilliseconds;
    final maxValue = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final rawPosition = _isScrubbing ? _scrubValue : state.position.inMilliseconds.toDouble();
    final value = rawPosition.clamp(0.0, maxValue).toDouble();
    final enabled = durationMs > 0;
    return Slider(
      value: value,
      max: maxValue,
      onChanged: enabled
          ? (next) => setState(() {
              _isScrubbing = true;
              _scrubValue = next;
            })
          : null,
      onChangeStart: enabled
          ? (next) {
              _hideTimer?.cancel();
              setState(() {
                _isScrubbing = true;
                _scrubValue = next;
              });
            }
          : null,
      onChangeEnd: (next) {
        final playback = _playback;
        if (playback != null) {
          unawaited(playback.seek(Duration(milliseconds: next.round())));
        }
        setState(() => _isScrubbing = false);
        _scheduleHide();
      },
    );
  }

  Widget _buildDanmakuComposer(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _danmakuInput,
              focusNode: _danmakuFocus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendDanmaku(),
              onTap: _showControls,
              decoration: InputDecoration(
                hintText: l10n.viewerDanmakuInputHint,
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                isDense: true,
                filled: true,
                fillColor: const Color(0x33FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          IconButton(
            onPressed: _sendDanmaku,
            tooltip: l10n.viewerDanmakuSend,
            color: Colors.white,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _handlePlaybackChanged() {
    if (!mounted) {
      return;
    }
    final state = _playback?.state;
    final playing = state?.isPlaying ?? false;
    if (playing != _wasPlaying) {
      _wasPlaying = playing;
      if (playing) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        _controlsVisible = true;
      }
    }
    if (state?.hasFailed ?? false) {
      _controlsVisible = true;
    }
    setState(() {});
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
      return;
    }
    _showControls();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!(_playback?.state.isPlaying ?? false)) {
      return;
    }
    _hideTimer = Timer(_controlsTimeout, () {
      if (!mounted) {
        return;
      }
      final typing = _danmakuFocus?.hasFocus ?? false;
      if (_isScrubbing || typing) {
        _scheduleHide();
        return;
      }
      if (!(_playback?.state.isPlaying ?? false)) {
        return;
      }
      setState(() => _controlsVisible = false);
    });
  }

  void _togglePlay() {
    final playback = _playback;
    if (playback == null) {
      return;
    }
    unawaited(playback.togglePlay());
    _showControls();
  }

  void _toggleDanmaku() {
    setState(() {
      _danmakuSettings = _danmakuSettings.copyWith(enabled: !_danmakuSettings.enabled);
    });
    _showControls();
  }

  Future<void> _openDanmakuSettings() async {
    _hideTimer?.cancel();
    final result = await showModalBottomSheet<DanmakuSettings>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DanmakuSettingsSheet(initial: _danmakuSettings),
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      setState(() => _danmakuSettings = result);
    }
    _showControls();
  }

  void _sendDanmaku() {
    final playback = _playback;
    final engine = _engine;
    final input = _danmakuInput;
    if (playback == null || engine == null || input == null) {
      return;
    }
    final text = input.text.trim();
    if (text.isEmpty) {
      return;
    }
    engine.addComment(
      comment: DanmakuComment(position: playback.state.position, text: text),
    );
    input.clear();
    FocusScope.of(context).unfocus();
    _showControls();
  }

  Future<void> _openEpisodes() async {
    final content = _content;
    if (content == null) {
      return;
    }
    _hideTimer?.cancel();
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.viewerEpisodes, style: Theme.of(context).textTheme.titleMedium),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: content.episodes.length,
                itemBuilder: (context, index) => ListTile(
                  selected: index == _episodeIndex,
                  title: Text(content.episodes[index].title),
                  onTap: () => Navigator.of(context).pop(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (selected != null && selected != _episodeIndex) {
      _switchEpisode(selected);
    }
    _showControls();
  }

  void _switchEpisode(int index) {
    final content = _content;
    final playback = _playback;
    if (content == null || playback == null || index < 0 || index >= content.episodes.length) {
      return;
    }
    final episode = content.episodes[index];
    setState(() => _episodeIndex = index);
    _engine?.setComments(episode.danmaku);
    _wasPlaying = false;
    unawaited(playback.open(episode.media));
    _showControls();
  }

  void _retry() {
    final episode = _episode;
    final playback = _playback;
    if (episode == null || playback == null) {
      return;
    }
    unawaited(playback.open(episode.media));
    _showControls();
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _isFullscreen = !_isFullscreen);
    _logger.fine('fullscreen: $_isFullscreen');
    await SystemChrome.setEnabledSystemUIMode(
      _isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (!mounted) {
      return;
    }
    if (_isFullscreen) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  static String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _PlaybackErrorView extends StatelessWidget {
  const _PlaybackErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
