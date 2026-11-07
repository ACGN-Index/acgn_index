import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/playback/video_playback_controller.dart';
import 'package:acgn_index/features/viewer/video_viewer_page.dart';
import 'package:acgn_index/features/viewer/viewer_providers.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVideoPlaybackController extends VideoPlaybackController {
  final List<ViewerMedia> opened = <ViewerMedia>[];
  VideoPlaybackState _state = const VideoPlaybackState();

  @override
  VideoPlaybackState get state => _state;

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
    _state = _state.copyWith(status: VideoPlaybackStatus.playing);
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _state = _state.copyWith(status: VideoPlaybackStatus.paused);
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
    notifyListeners();
  }
}

VideoViewerContent _content({String uri = 'https://example.invalid/video/1.m3u8'}) {
  return VideoViewerContent(
    title: '测试番剧',
    episodes: <VideoEpisode>[
      VideoEpisode(
        title: '第 1 集',
        media: ViewerMedia(uri: Uri.parse(uri)),
      ),
      VideoEpisode(
        title: '第 2 集',
        media: ViewerMedia(uri: Uri.parse('https://example.invalid/video/2.m3u8')),
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

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeVideoPlaybackController controller,
  VideoViewerContent content,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoPlaybackControllerFactoryProvider.overrideWithValue(() => controller),
      ],
      child: _wrap(VideoViewerPage(content: content)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('缺少内容参数时展示提示', (tester) async {
    await tester.pumpWidget(_wrap(const VideoViewerPage()));
    await tester.pump();

    expect(find.text('无法打开查看器'), findsWidgets);
    expect(find.text('缺少内容参数，请从详情页重新进入。'), findsOneWidget);
  });

  testWidgets('打开视频时使用当前集的播放源并展示标题', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller, _content());

    expect(controller.opened, hasLength(1));
    expect(controller.opened.single.uri.toString(), 'https://example.invalid/video/1.m3u8');
    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('第 1 集'), findsOneWidget);
  });

  testWidgets('关闭弹幕后隐藏输入框', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller, _content());
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('弹幕'));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('播放失败后展示错误并可重试', (tester) async {
    final controller = _FakeVideoPlaybackController();
    await _pumpPage(tester, controller, _content(uri: 'https://example.invalid/fail.mp4'));

    expect(find.text('视频加载失败，请检查网络或链接。'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(controller.opened, hasLength(2));
  });
}
