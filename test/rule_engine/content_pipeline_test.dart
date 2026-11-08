import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_content.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/pipeline/content_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pipeline_test_helpers.dart';

void main() {
  group('RuleContentPipeline', () {
    test('images 模式解析图片、绝对地址与素材请求头', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply(
          '<div class="reader"><img src="/a.jpg"><img src="https://cdn.test/b.jpg"></div>',
          headers: <String, String>{'content-type': 'text/html; charset=utf-8'},
        ),
      ]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(_imagesPack(), id: '42', chapter: _chapter());

      expect(client.requests.single.uri.toString(), 'https://api.test/chapter/1');
      expect(content, isA<ImagesContent>());
      final images = (content as ImagesContent).images;
      expect(images.map((image) => image.uri.toString()), <String>[
        'https://api.test/a.jpg',
        'https://cdn.test/b.jpg',
      ]);
      expect(images.first.headers['Referer'], 'https://api.test');
      expect(images.first.headers['X-Test'], '1');
      expect(images.first.headers['User-Agent'], isNotEmpty);
    });

    test('text 模式把 HTML body 切成段落并保留插图', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('''
{"data":{"title":"第一章","content":"<p>第一段</p><p>第二段</p>",
"images":[{"src":"/i1.jpg"},{"src":"/i2.jpg"}]}}
'''),
      ]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(_textPack(), id: '42', chapter: _chapter());

      final text = content as TextContent;
      expect(text.title, '第一章');
      expect(text.paragraphs, <String>['第一段', '第二段']);
      expect(text.images.map((image) => image.uri.toString()), <String>[
        'https://api.test/i1.jpg',
        'https://api.test/i2.jpg',
      ]);
    });

    test('video 模式解析多线路、类型与弹幕地址', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('''
{"data":{"title":"第一话","urls":["/v1.m3u8","https://cdn.test/v2.mp4"],
"types":["hls","mp4"],"qualities":["1080p","720p"],"danmaku":"/danmaku/1.xml"}}
'''),
      ]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(_videoPack(), id: '42', chapter: _chapter());

      final video = content as VideoContent;
      expect(video.title, '第一话');
      expect(video.sources.map((source) => source.uri.toString()), <String>[
        'https://api.test/v1.m3u8',
        'https://cdn.test/v2.mp4',
      ]);
      expect(video.sources.map((source) => source.type), <String?>['hls', 'mp4']);
      expect(video.sources.map((source) => source.quality), <String?>['1080p', '720p']);
      expect(video.danmakuUrl.toString(), 'https://api.test/danmaku/1.xml');
    });

    test('file 模式只解析地址，不发起请求', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(
        _filePack(),
        id: 'book-1',
        chapter: const TocEntry(
          id: 'v1',
          title: '第一卷',
          extra: <String, Object?>{'file': 'f1'},
        ),
      );

      expect(client.requests, isEmpty);
      final file = content as FileContent;
      expect(file.url.toString(), 'https://github.com/releases/book-1/f1');
      expect(file.format, 'epub');
      expect(file.size, 123);
    });

    test('resolve 二段请求字段注入正文地址模板', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('{"token":"abc"}'),
        const FakeReply('{"data":{"content":"正文"}}'),
      ]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(_resolvePack(), id: '42', chapter: _chapter());

      expect(client.requests, hasLength(2));
      expect(client.requests.first.uri.toString(), 'https://api.test/resolve/c1');
      expect(
        client.requests.last.uri.toString(),
        'https://api.test/content/c1?token=abc',
      );
      expect((content as TextContent).paragraphs, <String>['正文']);
    });

    test('video 模式 url 留空时直接使用目录直链、不发请求', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleContentPipeline(httpClient: client);

      final content = await pipeline.fetch(
        _inlineVideoPack(),
        id: '42',
        chapter: const TocEntry(
          id: 'c1',
          title: '第一话',
          url: 'https://cdn.test/ep1/index.m3u8',
        ),
      );

      expect(client.requests, isEmpty);
      final video = content as VideoContent;
      expect(video.title, '第一话');
      expect(video.sources.single.uri.toString(), 'https://cdn.test/ep1/index.m3u8');
      expect(video.sources.single.type, 'hls');
      expect(video.headers['Referer'], 'https://api.test');
    });

    test('未声明 content 能力时抛不支持异常', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleContentPipeline(httpClient: client);

      await expectLater(
        pipeline.fetch(
          testPack(capabilities: const <RuleCapability, CapabilityRule>{}),
          id: '42',
          chapter: _chapter(),
        ),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}

TocEntry _chapter() => const TocEntry(
  id: 'c1',
  title: '第一章',
  url: 'https://api.test/chapter/1',
  extra: <String, Object?>{'file': 'f1'},
);

RulePack _imagesPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.images,
      url: '{{chapter.url}}',
      headers: <String, String>{'X-Test': '1'},
      fields: <String, FieldRule>{
        'images': FieldRule(
          selector: '.reader img',
          attribute: 'src',
          multiple: true,
          absolute: true,
        ),
        'referer': FieldRule(constant: '{{baseUrl}}'),
      },
    ),
  },
);

RulePack _textPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.text,
      url: '{{chapter.url}}',
      fields: <String, FieldRule>{
        'title': FieldRule(jsonPath: r'$.data.title'),
        'body': FieldRule(jsonPath: r'$.data.content'),
        'images': FieldRule(
          jsonPath: r'$.data.images[*].src',
          multiple: true,
          absolute: true,
        ),
      },
    ),
  },
);

RulePack _videoPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.video,
      url: '{{chapter.url}}',
      fields: <String, FieldRule>{
        'title': FieldRule(jsonPath: r'$.data.title'),
        'urls': FieldRule(jsonPath: r'$.data.urls[*]', multiple: true, absolute: true),
        'type': FieldRule(jsonPath: r'$.data.types[*]', multiple: true),
        'quality': FieldRule(jsonPath: r'$.data.qualities[*]', multiple: true),
        'danmakuUrl': FieldRule(jsonPath: r'$.data.danmaku', absolute: true),
      },
    ),
  },
);

RulePack _filePack() => testPack(
  baseUrl: 'https://github.com',
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.file,
      url: 'https://github.com/releases/{{id}}/{{chapter.file}}',
      fields: <String, FieldRule>{
        'format': FieldRule(constant: 'epub'),
        'size': FieldRule(constant: '123'),
      },
    ),
  },
);

RulePack _inlineVideoPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.video,
      url: '',
      fields: <String, FieldRule>{
        'title': FieldRule(constant: '{{chapter.title}}'),
        'url': FieldRule(constant: '{{chapter.url}}'),
        'type': FieldRule(constant: 'hls'),
        'referer': FieldRule(constant: '{{baseUrl}}'),
      },
    ),
  },
);

RulePack _resolvePack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.content: ContentCapabilityRule(
      mode: ContentMode.text,
      url: '/content/{{chapter.id}}?token={{resolve.token}}',
      resolve: ResolveRule(
        url: '/resolve/{{chapter.id}}',
        fields: <String, FieldRule>{
          'token': FieldRule(jsonPath: r'$.token'),
        },
      ),
      fields: <String, FieldRule>{
        'body': FieldRule(jsonPath: r'$.data.content'),
      },
    ),
  },
);
