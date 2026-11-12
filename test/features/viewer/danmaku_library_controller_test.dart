import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/domain/repositories/danmaku_library_repository.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<DanmakuComment> _comments = <DanmakuComment>[
  DanmakuComment(position: Duration(seconds: 3), text: '图书馆'),
];

const List<DanmakuLibraryAnime> _animes = <DanmakuLibraryAnime>[
  DanmakuLibraryAnime(
    animeId: 3562,
    title: '月色真美',
    typeLabel: 'TV动画',
    episodes: <DanmakuLibraryEpisode>[
      DanmakuLibraryEpisode(episodeId: 101, title: '第1话'),
      DanmakuLibraryEpisode(episodeId: 102, title: '第2话'),
    ],
  ),
];

class _FakeDanmakuLibraryRepository implements DanmakuLibraryRepository {
  _FakeDanmakuLibraryRepository({this.failure});

  final Object? failure;
  final List<String> queries = <String>[];
  final List<int> fetched = <int>[];

  @override
  Future<List<DanmakuLibraryAnime>> searchEpisodes({
    required String keyword,
    required DanmakuLibraryConfig config,
  }) async {
    queries.add(keyword);
    if (failure != null) {
      throw failure!;
    }
    return _animes;
  }

  @override
  Future<List<DanmakuComment>> fetchComments({
    required int episodeId,
    required DanmakuLibraryConfig config,
  }) async {
    fetched.add(episodeId);
    if (failure != null) {
      throw failure!;
    }
    return _comments;
  }
}

ProviderContainer _container(_FakeDanmakuLibraryRepository repository) {
  final container = ProviderContainer(
    overrides: [
      danmakuLibraryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen<DanmakuLibraryState>(danmakuLibraryProvider, (_, _) {}, fireImmediately: true);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'danmaku_library_app_id': 'id',
      'danmaku_library_app_secret': 'secret',
    });
  });

  test('按作品与集数自动匹配并拉取弹幕', () async {
    final repository = _FakeDanmakuLibraryRepository();
    final container = _container(repository);

    final comments = await container
        .read(danmakuLibraryProvider.notifier)
        .autoMatch(workTitle: '月色真美', episodeTitle: '第2话');

    expect(comments, _comments);
    expect(repository.queries, <String>['月色真美']);
    expect(repository.fetched, <int>[102]);
    final state = container.read(danmakuLibraryProvider);
    expect(state.anime?.animeId, 3562);
    expect(state.episode?.episodeId, 102);
    expect(state.commentCount, 1);
    expect(state.status, DanmakuLibraryStatus.ready);
  });

  test('同一集重复匹配命中缓存，不再请求弹幕', () async {
    final repository = _FakeDanmakuLibraryRepository();
    final container = _container(repository);
    final controller = container.read(danmakuLibraryProvider.notifier);

    await controller.autoMatch(workTitle: '月色真美', episodeTitle: '第2话');
    await controller.autoMatch(workTitle: '月色真美', episodeTitle: '第2话');

    expect(repository.fetched, <int>[102]);
  });

  test('没有匹配到作品时返回空列表', () async {
    final container = _container(_FakeDanmakuLibraryRepository());

    final comments = await container
        .read(danmakuLibraryProvider.notifier)
        .autoMatch(workTitle: '完全不相关的作品', episodeTitle: '第1话');

    expect(comments, isEmpty);
    expect(container.read(danmakuLibraryProvider).status, DanmakuLibraryStatus.ready);
  });

  test('请求失败时记录失败状态且不影响播放', () async {
    final container = _container(
      _FakeDanmakuLibraryRepository(failure: const NetworkException('boom')),
    );

    final comments = await container
        .read(danmakuLibraryProvider.notifier)
        .autoMatch(workTitle: '月色真美', episodeTitle: '第1话');

    expect(comments, isEmpty);
    final state = container.read(danmakuLibraryProvider);
    expect(state.status, DanmakuLibraryStatus.failed);
    expect(state.errorMessage, 'boom');
  });
}
