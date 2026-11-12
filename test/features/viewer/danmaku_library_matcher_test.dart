import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEpisodeNumber', () {
    test('识别常见集数写法', () {
      expect(parseEpisodeNumber('第12集'), 12);
      expect(parseEpisodeNumber('第 03 话'), 3);
      expect(parseEpisodeNumber('EP05'), 5);
      expect(parseEpisodeNumber('S2E08'), 8);
      expect(parseEpisodeNumber('１２'), 12);
      expect(parseEpisodeNumber('12'), 12);
    });

    test('没有集数信息时返回 null', () {
      expect(parseEpisodeNumber('特别篇'), isNull);
      expect(parseEpisodeNumber('1080P'), isNull);
      expect(parseEpisodeNumber('12.5'), isNull);
      expect(parseEpisodeNumber(''), isNull);
    });
  });

  group('pickAnime', () {
    test('完全匹配优先于包含匹配', () {
      final animes = <DanmakuLibraryAnime>[
        const DanmakuLibraryAnime(animeId: 1, title: '月色真美 第二季'),
        const DanmakuLibraryAnime(animeId: 2, title: '月色真美'),
      ];

      expect(pickAnime(animes, '月色真美')?.animeId, 2);
    });

    test('没有相关结果时返回 null', () {
      final animes = <DanmakuLibraryAnime>[
        const DanmakuLibraryAnime(animeId: 1, title: '别的作品'),
      ];

      expect(pickAnime(animes, '月色真美'), isNull);
    });
  });

  group('pickEpisode', () {
    const episodes = <DanmakuLibraryEpisode>[
      DanmakuLibraryEpisode(episodeId: 1, title: '第1话'),
      DanmakuLibraryEpisode(episodeId: 2, title: '第2话'),
      DanmakuLibraryEpisode(episodeId: 3, title: '第3话'),
    ];

    test('按集数匹配', () {
      expect(pickEpisode(episodes, number: 2)?.episodeId, 2);
    });

    test('标题解析不到集数时按序号兜底', () {
      expect(
        pickEpisode(
          const <DanmakuLibraryEpisode>[
            DanmakuLibraryEpisode(episodeId: 11, title: '上'),
            DanmakuLibraryEpisode(episodeId: 12, title: '下'),
          ],
          number: 1,
        )?.episodeId,
        11,
      );
    });

    test('集数未知时取第一条，空列表返回 null', () {
      expect(pickEpisode(episodes)?.episodeId, 1);
      expect(pickEpisode(const <DanmakuLibraryEpisode>[]), isNull);
    });
  });
}
