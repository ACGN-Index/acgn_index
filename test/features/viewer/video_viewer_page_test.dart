import 'package:acgn_index/app/window/window_title.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/domain/repositories/danmaku_library_repository.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:acgn_index/features/viewer/player_window_controller.dart';
import 'package:acgn_index/features/viewer/video_viewer_page.dart';
import 'package:acgn_index/features/viewer/viewer_providers.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVideoPlaybackController extends VideoPlaybackController {
  final List<ViewerMedia> opened = <ViewerMedia>[];
  final List<Duration> seeks = <Duration>[];
  int pauseCount = 0;
  VideoPlaybackState _state = const VideoPlaybackState();

  @override
  VideoPlaybackState get state => _state;

  /// 模拟后端推送状态（例如 libmpv 在网络抖动时误报错误）。
  void emit(VideoPlaybackState next) {
    _state = next;
    notifyListeners();
  }

  @override
  Widget buildSurface(BuildContext context) => const ColoredBox(color: Color(0xFF000000));

  @override
  Future<void> open(ViewerMedia media) async {
    opened.add(media);
    _state = media.uri.toString().contains('fail')
        ? const VideoPlaybackState(status: VideoPlaybackStatus.failed)
        : const VideoPlaybackState(
            status: VideoPlaybackStatus.paused,
            duration: Duration(minutes: 1),
          );
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _state = _state.copyWith(status: VideoPlaybackStatus.playing, playing: true);
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _state = _state.copyWith(status: VideoPlaybackStatus.paused, playing: false);
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _state = _state.copyWith(position: position);
    notifyListeners();
  }
}

class _FakeWindowController implements PlayerWindowController {
  _FakeWindowController({this.isDesktop = false});

  @override
  final bool isDesktop;

  int fullscreenCalls = 0;
  int exitFullscreenCalls = 0;

  @override
  Future<void> enterFullscreen() async => fullscreenCalls++;

  @override
  Future<void> exitFullscreen() async => exitFullscreenCalls++;
}

class _FakeDanmakuLibraryRepository implements DanmakuLibraryRepository {
  @override
  Future<List<DanmakuLibraryAnime>> searchEpisodes({
    required String keyword,
    required DanmakuLibraryConfig config,
  }) async => const <DanmakuLibraryAnime>[];

  @override
  Future<List<DanmakuComment>> fetchComments({
    required int episodeId,
    required DanmakuLibraryConfig config,
  }) async => const <DanmakuComment>[];
}

class _FakeChapterSource implements ViewerChapterSource {
  _FakeChapterSource(this.chapters, this._loader);

  @override
  final List<ViewerChapterRef> chapters;

  final Future<ViewerLaunch> Function(ViewerChapterRef chapter) _loader;

  @override
  Future<ViewerLaunch> load(ViewerChapterRef chapter) => _loader(chapter);
}

VideoViewerContent _content({
  String uri = 'https://example.invalid/video/1.m3u8',
  ViewerChapterSource? chapterSource,
}) {
  return VideoViewerContent(
    title: '测试番剧',
    chapterTitle: '第 1 集',
    chapterSource: chapterSource,
    initialChapterKey: chapterSource?.chapters.first.key,
    episodes: <VideoEpisode>[
      VideoEpisode(
        title: '第 1 集 · 1080p',
        media: ViewerMedia(uri: Uri.parse(uri)),
      ),
      VideoEpisode(
        title: '第 1 集 · 720p',
        media: ViewerMedia(uri: Uri.parse('https://example.invalid/video/1b.m3u8')),
      ),
    ],
  );
}

Widget _wrap(Widget page) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  );
}

Future<WindowTitleController> _pumpPage(
  WidgetTester tester, {
  required _FakeVideoPlaybackController controller,
  VideoViewerContent? content,
  _FakeWindowController? window,
  List<String>? windowTitles,
}) async {
  final titles = windowTitles ?? <String>[];
  final titleController = WindowTitleController(apply: (title) async => titles.add(title));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoPlaybackControllerFactoryProvider.overrideWithValue(() => controller),
        playerWindowControllerProvider.overrideWithValue(window ?? _FakeWindowController()),
        danmakuLibraryRepositoryProvider.overrideWithValue(_FakeDanmakuLibraryRepository()),
        windowTitleControllerProvider.overrideWithValue(titleController),
      ],
      child: _wrap(VideoViewerPage(content: content ?? _content())),
    ),
  );
  await tester.pump();
  await tester.pump();
  return titleController;
}

double _chromeOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
  return opacity.opacity;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('缺少内容参数时展示提示', (tester) async {
    await tester.pumpWidget(_wrap(const VideoViewerPage()));
    await tester.pump();

    expect(find.text('无法打开查看器'), findsWidgets);
    expect(find.text('缺少内容参数，请从详情页重新进入。'), findsOneWidget);
  });

  testWidgets('打开视频时使用当前集的播放源并展示标题与全部剧集', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller: controller);

    expect(controller.opened, hasLength(1));
    expect(controller.opened.single.uri.toString(), 'https://example.invalid/video/1.m3u8');
    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('第 1 集'), findsWidgets);
    expect(find.text('全部剧集 · 1 集'), findsOneWidget);
  });

  testWidgets('窄屏窗口模式不显示选集按钮，弹幕输入框仍在控制栏内', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller: controller);

    expect(find.byTooltip('选集'), findsNothing);
    expect(find.byTooltip('弹幕'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // 不再有画面中央的播放按钮：只剩控制栏里的一个播放图标。
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('宽屏选集按钮切换侧栏显隐，收起后顶栏补上标题', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, controller: _FakeVideoPlaybackController());

    // 侧栏展示标题与剧集，顶栏不重复标题。
    expect(find.text('全部剧集 · 1 集'), findsOneWidget);
    expect(find.text('测试番剧'), findsOneWidget);
    final episodesButton = find.byTooltip('选集');
    expect(episodesButton, findsOneWidget);

    await tester.tap(episodesButton);
    await tester.pump();

    // 收起侧栏：列表消失，标题改由顶栏展示。
    expect(find.text('全部剧集 · 1 集'), findsNothing);
    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.byTooltip('选集'), findsOneWidget);

    await tester.tap(find.byTooltip('选集'));
    await tester.pump();

    expect(find.text('全部剧集 · 1 集'), findsOneWidget);
  });

  testWidgets('全屏时选集按钮打开选集面板', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final window = _FakeWindowController(isDesktop: true);
    await _pumpPage(
      tester,
      controller: _FakeVideoPlaybackController(),
      window: window,
    );

    await tester.tap(find.byTooltip('全屏').last);
    await tester.pump();
    await tester.pump();

    expect(window.fullscreenCalls, 1);
    expect(find.text('全部剧集 · 1 集'), findsNothing);

    // 进入全屏后会隐藏控制栏，先点一下画面唤出。
    await tester.tapAt(tester.getCenter(find.byType(VideoViewerPage)));
    await tester.pump(kDoubleTapTimeout);

    expect(find.byTooltip('选集'), findsOneWidget);

    await tester.tap(find.byTooltip('选集'));
    await tester.pumpAndSettle();

    expect(find.text('全部剧集 · 1 集'), findsOneWidget);
  });

  testWidgets('关闭弹幕后隐藏输入框', (tester) async {
    await _pumpPage(tester, controller: _FakeVideoPlaybackController());
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('弹幕'));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('播放失败后展示错误并可重试', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(
      tester,
      controller: controller,
      content: _content(uri: 'https://example.invalid/fail.mp4'),
    );

    expect(find.text('视频加载失败，请检查网络或链接。'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(controller.opened, hasLength(2));
  });

  testWidgets('状态被误标为失败但后端仍在播放时，暂停依然生效', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller: controller);

    controller.emit(
      const VideoPlaybackState(
        status: VideoPlaybackStatus.failed,
        playing: true,
        duration: Duration(minutes: 1),
        position: Duration(seconds: 51),
      ),
    );
    await tester.pump();

    expect(find.text('视频加载失败，请检查网络或链接。'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();

    expect(controller.pauseCount, 1);
  });

  testWidgets('长按后左右拖动会按位移跳转进度', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller: controller);

    final center = tester.getCenter(find.byType(VideoViewerPage));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.seeks, isNotEmpty);
    expect(controller.seeks.last, greaterThan(Duration.zero));
  });

  testWidgets('鼠标移动时显示控制栏', (tester) async {
    await _pumpPage(tester, controller: _FakeVideoPlaybackController());
    await tester.tapAt(tester.getCenter(find.byType(VideoViewerPage)));
    await tester.pump(kDoubleTapTimeout);
    expect(_chromeOpacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(VideoViewerPage)));
    await tester.pump();

    expect(_chromeOpacity(tester), 1);
  });

  testWidgets('窗口标题显示作品名与当前集数', (tester) async {
    final controller = _FakeVideoPlaybackController();
    final titles = <String>[];
    await _pumpPage(tester, controller: controller, windowTitles: titles);

    expect(titles.last, '测试番剧 - 第 1 集');
  });

  testWidgets('通过章节源切换章节会重新打开对应的播放源', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _FakeVideoPlaybackController();
    final titles = <String>[];
    final source = _FakeChapterSource(
      const <ViewerChapterRef>[
        ViewerChapterRef(key: 'e1', title: '第 1 集'),
        ViewerChapterRef(key: 'e2', title: '第 2 集'),
      ],
      (chapter) async => VideoViewerLaunch(
        VideoViewerContent(
          title: '测试番剧',
          chapterTitle: chapter.title,
          initialChapterKey: chapter.key,
          episodes: <VideoEpisode>[
            VideoEpisode(
              title: chapter.title,
              media: ViewerMedia(
                uri: Uri.parse('https://example.invalid/video/${chapter.key}.m3u8'),
              ),
            ),
          ],
        ),
      ),
    );
    await _pumpPage(
      tester,
      controller: controller,
      content: _content(chapterSource: source),
      windowTitles: titles,
    );

    expect(find.text('第 2 集'), findsOneWidget);

    await tester.tap(find.text('第 2 集'));
    await tester.pump();
    await tester.pump();

    expect(controller.opened, hasLength(2));
    expect(controller.opened.last.uri.toString(), 'https://example.invalid/video/e2.m3u8');
    expect(titles.last, '测试番剧 - 第 2 集');
  });
}
