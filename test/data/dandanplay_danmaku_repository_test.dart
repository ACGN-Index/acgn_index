import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/data/repositories/dandanplay_danmaku_repository.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rule_engine/pipeline_test_helpers.dart';

const DanmakuLibraryConfig _config = DanmakuLibraryConfig(
  appId: 'id',
  appSecret: 'secret',
);

DateTime _clock() => DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

void main() {
  group('DandanplayDanmakuRepository', () {
    test('搜索作品并解析剧集，请求带签名头', () async {
      final client = FakeHttpClient(<FakeReply>[
        FakeReply(
          jsonEncode(<String, Object?>{
            'errorCode': 0,
            'success': true,
            'animes': <Object?>[
              <String, Object?>{
                'animeId': 3562,
                'animeTitle': '月色真美',
                'typeDescription': 'TV动画',
                'episodes': <Object?>[
                  <String, Object?>{'episodeId': 101, 'episodeTitle': '第1话'},
                  <String, Object?>{'episodeId': 102, 'episodeTitle': '第2话'},
                ],
              },
            ],
          }),
        ),
      ]);
      final repository = DandanplayDanmakuRepository(httpClient: client, clock: _clock);

      final animes = await repository.searchEpisodes(keyword: ' 月色真美 ', config: _config);

      expect(animes, hasLength(1));
      expect(animes.single.animeId, 3562);
      expect(animes.single.typeLabel, 'TV动画');
      expect(animes.single.episodes.map((episode) => episode.episodeId), <int>[101, 102]);

      final request = client.requests.single;
      expect(request.uri.path, '/api/v2/search/episodes');
      expect(request.uri.queryParameters['anime'], '月色真美');
      expect(request.headers['X-AppId'], 'id');
      expect(request.headers['X-Timestamp'], '1700000000');
      expect(request.headers['X-Signature'], 'iTvN1ma3vKQxsG8wQjjpqtUV3bWCqgVXDl/t361gAzE=');
    });

    test('空关键词不发请求', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final repository = DandanplayDanmakuRepository(httpClient: client);

      expect(await repository.searchEpisodes(keyword: '  ', config: _config), isEmpty);
      expect(client.requests, isEmpty);
    });

    test('弹幕解析时间、模式与颜色', () async {
      final client = FakeHttpClient(<FakeReply>[
        FakeReply(
          jsonEncode(<String, Object?>{
            'count': 4,
            'comments': <Object?>[
              <String, Object?>{'cid': 1, 'p': '12.5,1,16711680,uid', 'm': '滚动'},
              <String, Object?>{'cid': 2, 'p': '13,4,65280,uid', 'm': '底部'},
              <String, Object?>{'cid': 3, 'p': '14,5,255,uid', 'm': '顶部'},
              <String, Object?>{'cid': 4, 'p': 'broken', 'm': '忽略'},
            ],
          }),
        ),
      ]);
      final repository = DandanplayDanmakuRepository(httpClient: client);

      final comments = await repository.fetchComments(episodeId: 101, config: _config);

      expect(comments, hasLength(3));
      expect(comments[0].position, const Duration(milliseconds: 12500));
      expect(comments[0].mode, DanmakuMode.scroll);
      expect(comments[0].color, 0xFFFF0000);
      expect(comments[1].mode, DanmakuMode.bottom);
      expect(comments[2].mode, DanmakuMode.top);
      expect(comments[2].color, 0xFF0000FF);
      expect(client.requests.single.uri.path, '/api/v2/comment/101');
      expect(client.requests.single.uri.queryParameters['withRelated'], 'true');
    });

    test('未配置密钥时不带鉴权头，支持自建地址', () async {
      final client = FakeHttpClient(<FakeReply>[
        FakeReply(jsonEncode(<String, Object?>{'count': 0, 'comments': <Object?>[]})),
      ]);
      final repository = DandanplayDanmakuRepository(httpClient: client);
      const config = DanmakuLibraryConfig(baseUrl: 'https://danmaku.proxy/api');

      await repository.fetchComments(episodeId: 7, config: config);

      final request = client.requests.single;
      expect(
        request.uri.toString(),
        'https://danmaku.proxy/api/api/v2/comment/7?withRelated=true&chConvert=1',
      );
      expect(request.headers.containsKey('X-AppId'), isFalse);
    });

    test('HTTP 失败、业务错误与非法 JSON 都抛网络异常', () async {
      final failing = DandanplayDanmakuRepository(
        httpClient: FakeHttpClient(<FakeReply>[const FakeReply('{}', statusCode: 401)]),
      );
      await expectLater(
        failing.searchEpisodes(keyword: '作品', config: _config),
        throwsA(isA<NetworkException>()),
      );

      final businessError = DandanplayDanmakuRepository(
        httpClient: FakeHttpClient(<FakeReply>[
          FakeReply(jsonEncode(<String, Object?>{'errorCode': 1001, 'errorMessage': '签名错误'})),
        ]),
      );
      await expectLater(
        businessError.searchEpisodes(keyword: '作品', config: _config),
        throwsA(isA<NetworkException>()),
      );

      final malformed = DandanplayDanmakuRepository(
        httpClient: FakeHttpClient(<FakeReply>[const FakeReply('not json')]),
      );
      await expectLater(
        malformed.searchEpisodes(keyword: '作品', config: _config),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
