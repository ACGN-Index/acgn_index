import 'dart:async';

import 'package:acgn_index/app/window/window_title.dart';
import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_engine.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_controller.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_sheet.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_overlay.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings_sheet.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:acgn_index/features/viewer/player_settings.dart';
import 'package:acgn_index/features/viewer/player_window_controller.dart';
import 'package:acgn_index/features/viewer/viewer_providers.dart';
import 'package:acgn_index/features/viewer/widgets/video_progress_bar.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_chapter_panel.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_message_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

/// 视频查看器：窗口模式为「视频 + 选集」页面，全屏时为沉浸式播放器。
class VideoViewerPage extends ConsumerStatefulWidget {
  const VideoViewerPage({this.content, super.key});

  final VideoViewerContent? content;

  @override
  ConsumerState<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends ConsumerState<VideoViewerPage>
    with WindowTitleOwner<VideoViewerPage> {
  static final Logger _logger = AppLogger.of('viewer.video');
  static const Duration _controlsTimeout = Duration(seconds: 3);

  /// 非全屏布局的宽度断点：窄屏上下堆叠，宽屏视频 + 侧栏。
  static const double _wideBreakpoint = 900;

  VideoPlaybackController? _playback;
  DanmakuEngine? _engine;
  PlayerWindowController? _window;
  TextEditingController? _danmakuInput;
  FocusNode? _danmakuFocus;
  Timer? _hideTimer;
  DanmakuSettings _danmakuSettings = const DanmakuSettings();

  /// true = 真全屏（沉浸）；窗口模式下宽屏是否显示侧栏由 [_sidebarVisible] 决定。
  bool _immersive = false;
  bool _sidebarVisible = true;
  List<VideoEpisode> _episodes = const <VideoEpisode>[];
  int _episodeIndex = 0;
  List<DanmakuComment> _libraryComments = const <DanmakuComment>[];
  String? _chapterKey;
  String _chapterTitle = '';
  bool _chapterLoading = false;
  bool _controlsVisible = true;
  bool _hoverShowsControls = true;
  bool _isScrubbing = false;
  bool _wasPlaying = false;
  double _scrubValue = 0;
  double _playerWidth = 1;
  bool _isWide = false;
  double _dragSeekStartX = 0;
  Duration _dragSeekBase = Duration.zero;
  Duration? _dragSeekTarget;
  DateTime _lastHoverSchedule = DateTime.fromMillisecondsSinceEpoch(0);

  VideoViewerContent? get _content => widget.content;

  VideoEpisode? get _episode {
    if (_episodes.isEmpty) {
      return null;
    }
    final index = _episodeIndex.clamp(0, _episodes.length - 1);
    return _episodes[index];
  }

  List<ViewerChapterRef> get _chapterRefs {
    final content = _content;
    final source = content?.chapterSource;
    if (source != null && source.chapters.isNotEmpty) {
      return source.chapters;
    }
    if (content == null) {
      return const <ViewerChapterRef>[];
    }
    return <ViewerChapterRef>[
      ViewerChapterRef(key: _chapterKey ?? 'current', title: _chapterTitle),
    ];
  }

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    if (content == null || content.episodes.isEmpty) {
      return;
    }
    _episodes = content.episodes;
    _episodeIndex = content.safeInitialEpisodeIndex;
    _chapterKey = content.initialChapterKey ?? content.chapterSource?.chapters.firstOrNull?.key;
    _chapterTitle = content.chapterTitle ?? _episodes[_episodeIndex].title;
    claimWindowTitle(
      ref.read(windowTitleControllerProvider),
      composeWindowTitle(content.title, _chapterTitle),
    );
    _danmakuInput = TextEditingController();
    _danmakuFocus = FocusNode();
    _window = ref.read(playerWindowControllerProvider);
    final playback = ref.read(videoPlaybackControllerFactoryProvider)();
    _playback = playback..addListener(_handlePlaybackChanged);
    _engine = DanmakuEngine(comments: _episodes[_episodeIndex].danmaku);
    unawaited(playback.open(_episodes[_episodeIndex].media));
    unawaited(_loadLibraryDanmaku());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playback?.removeListener(_handlePlaybackChanged);
    _playback?.dispose();
    _engine?.dispose();
    _danmakuInput?.dispose();
    _danmakuFocus?.dispose();
    if (_immersive) {
      unawaited(_window?.exitFullscreen());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final playback = _playback;
    final engine = _engine;
    if (content == null || _episodes.isEmpty || playback == null || engine == null) {
      return ViewerMessagePage(
        icon: Icons.movie_filter_outlined,
        title: l10n.viewerContentMissingTitle,
        message: l10n.viewerContentMissingBody,
      );
    }
    _hoverShowsControls =
        ref.watch(playerSettingsProvider).value?.showControlsOnPointerMove ?? true;

    final immersive = _immersive;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: immersive ? _buildImmersive(l10n) : _buildTheater(l10n),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && _immersive) {
      unawaited(_exitImmersive());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 非全屏：窄屏视频在上、列表在下；宽屏视频在左、选集侧栏在右。
  ///
  /// 宽屏让播放器铺满整列高度（画面在其中留黑边），
  /// 这样上下的控制区域才贴住窗口边缘，不会出现悬空的灰条。
  Widget _buildTheater(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        _isWide = wide;
        if (wide) {
          return SafeArea(
            child: Row(
              children: <Widget>[
                Expanded(child: _buildPlayer(l10n)),
                // 「窗口全屏」在宽屏下就是收起侧栏，让画面铺满整个窗口。
                if (_sidebarVisible)
                  SizedBox(
                    width: 360,
                    child: Material(
                      color: const Color(0xFF141414),
                      child: SafeArea(left: false, child: _buildChapterPanel(scrollable: true)),
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.68),
              child: AspectRatio(aspectRatio: 16 / 9, child: _buildPlayer(l10n)),
            ),
            Expanded(
              child: Material(
                color: const Color(0xFF141414),
                child: SingleChildScrollView(
                  child: _buildChapterPanel(scrollable: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImmersive(AppLocalizations l10n) {
    return SizedBox.expand(child: _buildPlayer(l10n));
  }

  Widget _buildChapterPanel({required bool scrollable}) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final library = ref.watch(danmakuLibraryProvider);
    return ViewerChapterPanel(
      chapters: _chapterRefs,
      currentChapterKey: _chapterKey,
      onSelectChapter: (chapter) => unawaited(_selectChapter(chapter)),
      lines: _episodes.map((episode) => episode.title).toList(growable: false),
      currentLineIndex: _episodeIndex,
      onSelectLine: _switchLine,
      loading: _chapterLoading,
      scrollable: scrollable,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            content?.title ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_chapterTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _chapterTitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _libraryStatusLabel(l10n, library),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(AppLocalizations l10n) {
    final playback = _playback;
    final engine = _engine;
    if (playback == null || engine == null) {
      return const SizedBox.shrink();
    }
    final state = playback.state;
    final immersive = _immersive;

    return ClipRect(
      child: Stack(
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
          _buildGestureLayer(),
          if (state.isLoading || (state.buffering && state.isPlaying))
            const Center(child: CircularProgressIndicator()),
          if (state.hasFailed)
            _PlaybackErrorView(
              message: l10n.viewerPlaybackError,
              retryLabel: l10n.viewerRetry,
              onRetry: _retry,
            ),
          if (_dragSeekTarget != null) _buildSeekPreview(),
          if (_chapterLoading)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildChrome(l10n, state, immersive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _playerWidth = constraints.maxWidth <= 0 ? 1 : constraints.maxWidth;
        return MouseRegion(
          cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (event) {
            if (!_hoverShowsControls) {
              return;
            }
            final now = DateTime.now();
            if (now.difference(_lastHoverSchedule) < const Duration(milliseconds: 400)) {
              return;
            }
            _lastHoverSchedule = now;
            if (!_controlsVisible) {
              setState(() => _controlsVisible = true);
            }
            _scheduleHide();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _togglePlay,
            onLongPressStart: (details) => _startDragSeek(details.localPosition),
            onLongPressMoveUpdate: (details) => _updateDragSeek(details.localPosition),
            onLongPressEnd: (details) => _endDragSeek(),
          ),
        );
      },
    );
  }

  Widget _buildSeekPreview() {
    final playback = _playback;
    final target = _dragSeekTarget;
    if (playback == null || target == null) {
      return const SizedBox.shrink();
    }
    final forward = target >= _dragSeekBase;
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  forward ? Icons.fast_forward : Icons.fast_rewind,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatDuration(_dragSeekBase)} → ${_formatDuration(target)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChrome(
    AppLocalizations l10n,
    VideoPlaybackState state,
    bool immersive,
  ) {
    return Column(
      children: <Widget>[
        _buildTopBar(l10n, immersive),
        const Spacer(),
        _buildBottomBar(l10n, state, immersive),
      ],
    );
  }

  /// 播放器铺满整屏、没有列表可看时才在顶栏显示标题。
  bool get _showsTitleInTopBar => _immersive || (_isWide && !_sidebarVisible);

  Widget _buildTopBar(AppLocalizations l10n, bool immersive) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 4, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: <Widget>[
          _bareIconButton(
            onPressed: _handleBack,
            tooltip: l10n.viewerBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          // 标题在下方列表或右侧栏里已经展示；只有它们不可见时才在顶栏补上。
          if (_showsTitleInTopBar)
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
                    _chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          _FullscreenButton(
            immersive: _immersive,
            tooltip: _immersive ? l10n.viewerExitFullscreen : l10n.viewerFullscreen,
            onTap: _immersive ? _exitImmersive : _enterImmersive,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    AppLocalizations l10n,
    VideoPlaybackState state,
    bool immersive,
  ) {
    final bottomInset = immersive ? MediaQuery.paddingOf(context).bottom : 0.0;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 4, 8, 4 + bottomInset),
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
          const SizedBox(height: 2),
          _buildControlRow(l10n, state, immersive),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlaybackState state) {
    final durationMs = state.duration.inMilliseconds;
    final maxValue = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final rawPosition = _isScrubbing ? _scrubValue : state.position.inMilliseconds.toDouble();
    final value = durationMs <= 0 ? 0.0 : (rawPosition / maxValue).clamp(0.0, 1.0);
    final buffered = durationMs <= 0
        ? 0.0
        : (state.buffered.inMilliseconds / maxValue).clamp(0.0, 1.0);
    return VideoProgressBar(
      value: value.toDouble(),
      buffered: buffered.toDouble(),
      enabled: durationMs > 0,
      onChangeStart: (fraction) {
        _hideTimer?.cancel();
        setState(() {
          _isScrubbing = true;
          _scrubValue = maxValue * fraction;
        });
      },
      onChanged: (fraction) => setState(() => _scrubValue = maxValue * fraction),
      onChangeEnd: (fraction) {
        final target = Duration(milliseconds: (maxValue * fraction).round());
        unawaited(_playback?.seek(target));
        setState(() => _isScrubbing = false);
        _scheduleHide();
      },
    );
  }

  Widget _buildControlRow(
    AppLocalizations l10n,
    VideoPlaybackState state,
    bool immersive,
  ) {
    final moduleButton = _buildModuleButton(l10n, immersive);
    return Row(
      children: <Widget>[
        _bareIconButton(
          onPressed: _togglePlay,
          tooltip: state.isPlaying ? l10n.viewerPause : l10n.viewerPlay,
          icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
        ),
        Text(
          '${_formatDuration(_isScrubbing ? Duration(milliseconds: _scrubValue.round()) : state.position)}'
          ' / ${_formatDuration(state.duration)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        if (_danmakuSettings.enabled)
          Expanded(child: _buildDanmakuComposer(l10n))
        else
          const Spacer(),
        _bareIconButton(
          onPressed: _toggleDanmaku,
          tooltip: l10n.viewerDanmaku,
          icon: Icon(
            _danmakuSettings.enabled ? Icons.subtitles : Icons.subtitles_off,
            color: _danmakuSettings.enabled ? Colors.white : Colors.white38,
          ),
        ),
        _bareIconButton(
          onPressed: _openDanmakuSettings,
          tooltip: l10n.viewerDanmakuSettings,
          icon: const Icon(Icons.tune, color: Colors.white),
        ),
        ?moduleButton,
        _FullscreenButton(
          immersive: _immersive,
          tooltip: _immersive ? l10n.viewerExitFullscreen : l10n.viewerFullscreen,
          onTap: _immersive ? _exitImmersive : _enterImmersive,
        ),
      ],
    );
  }

  /// 选集入口。
  ///
  /// - 窄屏窗口模式：选集列表就在下方，不显示按钮。
  /// - 宽屏窗口模式：按钮切换侧栏显隐（收起侧栏 = 画面铺满窗口）。
  /// - 全屏（沉浸）：列表不可见，按钮打开选集面板。
  Widget? _buildModuleButton(AppLocalizations l10n, bool immersive) {
    if (immersive) {
      return _bareIconButton(
        onPressed: _openEpisodes,
        tooltip: l10n.viewerEpisodes,
        icon: const Icon(Icons.playlist_play, color: Colors.white),
      );
    }
    if (!_isWide) {
      return null;
    }
    return _bareIconButton(
      onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
      tooltip: l10n.viewerEpisodes,
      icon: Icon(
        _sidebarVisible ? Icons.playlist_play : Icons.view_sidebar_outlined,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDanmakuComposer(AppLocalizations l10n) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _danmakuInput,
        focusNode: _danmakuFocus,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: Colors.white,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendDanmaku(),
        onTap: _showControls,
        decoration: InputDecoration(
          hintText: l10n.viewerDanmakuInputHint,
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          isDense: true,
          filled: true,
          fillColor: const Color(0x33FFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          suffixIcon: _bareIconButton(
            onPressed: _sendDanmaku,
            tooltip: l10n.viewerDanmakuSend,
            icon: const Icon(Icons.send, color: Colors.white, size: 18),
          ),
          suffixIconConstraints: const BoxConstraints.tightFor(width: 36, height: 32),
        ),
      ),
    );
  }

  Widget _bareIconButton({
    required VoidCallback onPressed,
    required String tooltip,
    required Widget icon,
    double size = 36,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
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

  void _startDragSeek(Offset position) {
    final playback = _playback;
    if (playback == null || playback.state.duration <= Duration.zero) {
      return;
    }
    _hideTimer?.cancel();
    _dragSeekStartX = position.dx;
    _dragSeekBase = playback.state.position;
    setState(() => _dragSeekTarget = _dragSeekBase);
  }

  void _updateDragSeek(Offset position) {
    final playback = _playback;
    final duration = playback?.state.duration ?? Duration.zero;
    if (playback == null || duration <= Duration.zero) {
      return;
    }
    final ratio = _playerWidth <= 0 ? 0.0 : (position.dx - _dragSeekStartX) / _playerWidth;
    final deltaMs = (duration.inMilliseconds * ratio).round();
    final targetMs = (_dragSeekBase.inMilliseconds + deltaMs).clamp(
      0,
      duration.inMilliseconds,
    );
    setState(() => _dragSeekTarget = Duration(milliseconds: targetMs));
  }

  void _endDragSeek() {
    final target = _dragSeekTarget;
    _dragSeekTarget = null;
    if (target == null) {
      return;
    }
    unawaited(_playback?.seek(target));
    setState(() {});
    _showControls();
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

  String _libraryStatusLabel(AppLocalizations l10n, DanmakuLibraryState library) {
    final anime = library.anime;
    final episode = library.episode;
    if (anime != null && episode != null) {
      return l10n.viewerDanmakuLibraryMatchedCount(
        anime.title,
        episode.title,
        library.commentCount,
      );
    }
    return switch (library.status) {
      DanmakuLibraryStatus.searching ||
      DanmakuLibraryStatus.loading => l10n.viewerDanmakuLibraryLoading,
      DanmakuLibraryStatus.failed => l10n.viewerDanmakuLibraryFailed,
      _ => l10n.viewerDanmakuLibraryIdle,
    };
  }

  Future<void> _openDanmakuSettings() async {
    _hideTimer?.cancel();
    final library = ref.read(danmakuLibraryProvider);
    final result = await showModalBottomSheet<DanmakuSettingsResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DanmakuSettingsSheet(
        initial: _danmakuSettings,
        libraryLabel: _libraryStatusLabel(AppLocalizations.of(context), library),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      setState(() => _danmakuSettings = result.settings);
    }
    if (result?.openLibrary ?? false) {
      await _openDanmakuLibrary();
      return;
    }
    _showControls();
  }

  Future<void> _openDanmakuLibrary() async {
    _hideTimer?.cancel();
    final content = _content;
    if (content == null) {
      return;
    }
    final comments = await showModalBottomSheet<List<DanmakuComment>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => DanmakuLibrarySheet(initialQuery: content.title),
    );
    if (!mounted) {
      return;
    }
    if (comments != null) {
      setState(() => _libraryComments = comments);
      _applyDanmaku();
    }
    _showControls();
  }

  Future<void> _loadLibraryDanmaku() async {
    final content = _content;
    if (content == null || !mounted) {
      return;
    }
    final chapterTitle = _chapterTitle;
    final comments = await ref
        .read(danmakuLibraryProvider.notifier)
        .autoMatch(workTitle: content.title, episodeTitle: chapterTitle);
    if (!mounted || chapterTitle != _chapterTitle || comments.isEmpty) {
      return;
    }
    setState(() => _libraryComments = comments);
    _applyDanmaku();
  }

  void _applyDanmaku() {
    final engine = _engine;
    final episode = _episode;
    if (engine == null || episode == null) {
      return;
    }
    final merged = <DanmakuComment>[...episode.danmaku, ..._libraryComments]
      ..sort((a, b) => a.position.compareTo(b.position));
    engine.setComments(merged);
    engine.seek(_playback?.state.position ?? Duration.zero);
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
    _hideTimer?.cancel();
    final selected = await showModalBottomSheet<ViewerChapterRef>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: ViewerChapterPanel(
          chapters: _chapterRefs,
          currentChapterKey: _chapterKey,
          onSelectChapter: (chapter) => Navigator.of(context).pop(chapter),
          lines: _episodes.map((episode) => episode.title).toList(growable: false),
          currentLineIndex: _episodeIndex,
          onSelectLine: (index) {
            Navigator.of(context).pop();
            _switchLine(index);
          },
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (selected != null) {
      await _selectChapter(selected);
    }
    _showControls();
  }

  Future<void> _selectChapter(ViewerChapterRef chapter) async {
    final source = _content?.chapterSource;
    if (source == null || chapter.key == _chapterKey) {
      _showControls();
      return;
    }
    setState(() => _chapterLoading = true);
    try {
      final launch = await source.load(chapter);
      if (!mounted) {
        return;
      }
      if (launch is! VideoViewerLaunch || launch.content.episodes.isEmpty) {
        throw const UnsupportedCapabilityException('该章节没有可播放的线路');
      }
      final content = launch.content;
      final index = content.safeInitialEpisodeIndex;
      final episode = content.episodes[index];
      setState(() {
        _chapterLoading = false;
        _chapterKey = chapter.key;
        _chapterTitle = content.chapterTitle ?? chapter.title;
        _episodes = content.episodes;
        _episodeIndex = index;
        _libraryComments = const <DanmakuComment>[];
      });
      _engine?.setComments(episode.danmaku);
      unawaited(_playback?.open(episode.media));
      setWindowTitle(
        composeWindowTitle(_content?.title ?? content.title, _chapterTitle),
      );
      _wasPlaying = false;
      unawaited(_loadLibraryDanmaku());
    } on Object catch (error, stackTrace) {
      _logger.warning('切换章节失败：${chapter.key}', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _chapterLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).viewerChapterLoadFailed)),
      );
    }
    _showControls();
  }

  void _switchLine(int index) {
    if (index == _episodeIndex || index < 0 || index >= _episodes.length) {
      return;
    }
    setState(() => _episodeIndex = index);
    _applyDanmaku();
    unawaited(_playback?.open(_episodes[index].media));
    _wasPlaying = false;
    _showControls();
  }

  Future<void> _enterImmersive() async {
    setState(() => _immersive = true);
    await _window?.enterFullscreen();
    if (!mounted) {
      return;
    }
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  Future<void> _exitImmersive() async {
    await _window?.exitFullscreen();
    if (!mounted) {
      return;
    }
    setState(() {
      _immersive = false;
      _controlsVisible = true;
    });
  }

  void _retry() {
    final episode = _episode;
    if (episode == null) {
      return;
    }
    unawaited(_playback?.open(episode.media));
    _showControls();
  }

  void _handleBack() {
    if (_immersive) {
      unawaited(_exitImmersive());
      return;
    }
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

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({
    required this.immersive,
    required this.tooltip,
    required this.onTap,
  });

  final bool immersive;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            immersive ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
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
