import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/repositories/rule_work_repository.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_content.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:acgn_index/rule_engine/pipeline/content_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/detail_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/toc_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/sources/sources_test_helpers.dart';

void main() {
  group('RuleWorkRepository', () {
    test('加载详情并把 search.volumes 传给目录流水线', () async {
      const detail = WorkDetail(title: '作品A');
      const toc = TocResult(
        entries: <TocEntry>[TocEntry(id: 'c1', title: '第一章')],
      );
      final detailService = _FakeDetailService(detail);
      final tocService = _FakeTocService(toc);
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(
          capabilities: const <RuleCapability>{
            RuleCapability.detail,
            RuleCapability.toc,
          },
        ),
      ]);
      addTearDown(sources.close);
      final repository = RuleWorkRepository(
        sources,
        detailService,
        tocService,
        _FakeContentService(const ImagesContent(title: '作品A', images: <ContentMedia>[])),
      );

      final work = await repository.loadWork(_item());

      expect(work.title, '作品A');
      expect(work.source.id, 'rule.test');
      expect(work.toc.entries.single.title, '第一章');
      expect(detailService.calls.single, '42');
      expect(tocService.searchResult?.extra['volumes'], isNotNull);
    });

    test('缺少 detail / toc 能力时用搜索项兜底', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(capabilities: const <RuleCapability>{RuleCapability.search}),
      ]);
      addTearDown(sources.close);
      final repository = RuleWorkRepository(
        sources,
        _FakeDetailService(const WorkDetail(title: '不应调用')),
        _FakeTocService(TocResult.empty),
        _FakeContentService(const ImagesContent(title: '不应调用', images: <ContentMedia>[])),
      );

      final work = await repository.loadWork(_item());

      expect(work.detail.title, '作品A');
      expect(work.detail.author, '作者A');
      expect(work.detail.url, 'https://example.invalid/work/42');
      expect(work.toc.isEmpty, isTrue);
    });

    test('规则不存在时抛存储异常', () async {
      final sources = FakeRuleSourceRepository();
      addTearDown(sources.close);
      final repository = RuleWorkRepository(
        sources,
        _FakeDetailService(const WorkDetail(title: '作品')),
        _FakeTocService(TocResult.empty),
        _FakeContentService(const ImagesContent(title: '作品', images: <ContentMedia>[])),
      );

      await expectLater(repository.loadWork(_item()), throwsA(isA<StorageException>()));
    });

    test('图片内容映射为漫画查看器', () async {
      final launch = await _loadLaunch(
        ImagesContent(
          title: '作品A',
          images: <ContentMedia>[
            ContentMedia(uri: Uri.parse('https://img.test/1.jpg')),
          ],
        ),
      );

      expect(launch, isA<ComicViewerLaunch>());
      final content = (launch as ComicViewerLaunch).content;
      expect(content.chapters.single.pages.single.uri.host, 'img.test');
    });

    test('文本内容映射为小说查看器', () async {
      final launch = await _loadLaunch(
        const TextContent(title: '作品A', paragraphs: <String>['第一段', '第二段']),
      );

      expect(launch, isA<NovelViewerLaunch>());
      expect((launch as NovelViewerLaunch).content.chapters.single.paragraphs, <String>[
        '第一段',
        '第二段',
      ]);
    });

    test('视频内容映射为视频查看器与多线路选集', () async {
      final launch = await _loadLaunch(
        VideoContent(
          title: '作品A',
          sources: <VideoSource>[
            VideoSource(
              uri: Uri.parse('https://media.test/1.m3u8'),
              type: 'hls',
              quality: '1080p',
            ),
            VideoSource(uri: Uri.parse('https://media.test/2.mp4'), type: 'mp4'),
          ],
        ),
      );

      expect(launch, isA<VideoViewerLaunch>());
      final content = (launch as VideoViewerLaunch).content;
      expect(content.episodes, hasLength(2));
      expect(content.episodes.first.title, contains('1080p'));
      expect(content.episodes.first.media.uri.toString(), 'https://media.test/1.m3u8');
    });

    test('文件内容映射为文件地址', () async {
      final launch = await _loadLaunch(
        FileContent(
          title: '作品A',
          url: Uri.parse('https://file.test/book.epub'),
          format: 'epub',
        ),
      );

      expect(launch, isA<FileViewerLaunch>());
      expect((launch as FileViewerLaunch).format, 'epub');
    });

    test('没有 content 能力时抛不支持异常', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(capabilities: const <RuleCapability>{RuleCapability.search}),
      ]);
      addTearDown(sources.close);
      final repository = RuleWorkRepository(
        sources,
        _FakeDetailService(const WorkDetail(title: '作品A')),
        _FakeTocService(TocResult.empty),
        _FakeContentService(const ImagesContent(title: '作品A', images: <ContentMedia>[])),
      );
      final work = await repository.loadWork(_item());

      await expectLater(
        repository.loadChapter(work, const TocEntry(id: 'c1', title: '第一章')),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}

Future<ViewerLaunch> _loadLaunch(RuleContent content) async {
  final sources = FakeRuleSourceRepository(<RuleSource>[
    _source(capabilities: const <RuleCapability>{RuleCapability.content}),
  ]);
  addTearDown(sources.close);
  final repository = RuleWorkRepository(
    sources,
    _FakeDetailService(const WorkDetail(title: '作品A')),
    _FakeTocService(TocResult.empty),
    _FakeContentService(content),
  );
  final work = await repository.loadWork(_item());
  return repository.loadChapter(work, const TocEntry(id: 'c1', title: '第一章'));
}

DiscoverItem _item() => DiscoverItem(
  ruleId: 'rule.test',
  ruleName: 'Test',
  type: MediaType.comic,
  origin: RuleSourceOrigin.imported,
  adult: false,
  id: '42',
  title: '作品A',
  author: '作者A',
  url: Uri.parse('https://example.invalid/work/42'),
  extra: const <String, Object?>{
    'volumes': <Map<String, String>>[
      <String, String>{'id': 'v1', 'title': '第一卷'},
    ],
  },
);

RuleSource _source({required Set<RuleCapability> capabilities}) {
  final rules = <RuleCapability, CapabilityRule>{
    if (capabilities.contains(RuleCapability.search))
      RuleCapability.search: const SearchCapabilityRule(url: '/search'),
    if (capabilities.contains(RuleCapability.detail))
      RuleCapability.detail: const DetailCapabilityRule(url: '/work/{{id}}'),
    if (capabilities.contains(RuleCapability.toc))
      RuleCapability.toc: const TocCapabilityRule(url: '/toc/{{id}}'),
    if (capabilities.contains(RuleCapability.content))
      RuleCapability.content: const ContentCapabilityRule(
        mode: ContentMode.images,
        url: '/content/{{chapter.id}}',
      ),
  };
  return RuleSource(
    pack: RulePack(
      schemaVersion: kSupportedSchemaVersion,
      meta: const RuleMeta(
        id: 'rule.test',
        name: 'Test',
        type: MediaType.comic,
        baseUrl: 'https://example.invalid',
        version: '1.0.0',
        author: 'tester',
        lang: 'zh',
      ),
      capabilities: rules,
    ),
    enabled: true,
    installedAt: DateTime(2026),
  );
}

class _FakeDetailService implements RuleDetailService {
  _FakeDetailService(this.detail);

  final WorkDetail detail;
  final List<String> calls = <String>[];

  @override
  Future<WorkDetail> fetch(RulePack pack, {required String id, String? url}) async {
    calls.add(id);
    return detail;
  }
}

class _FakeTocService implements RuleTocService {
  _FakeTocService(this.toc);

  final TocResult toc;
  SearchResult? searchResult;

  @override
  Future<TocResult> fetch(
    RulePack pack, {
    required String id,
    String? url,
    WorkDetail? detail,
    SearchResult? searchResult,
  }) async {
    this.searchResult = searchResult;
    return toc;
  }
}

class _FakeContentService implements RuleContentService {
  _FakeContentService(this.content);

  final RuleContent content;

  @override
  Future<RuleContent> fetch(
    RulePack pack, {
    required String id,
    required TocEntry chapter,
    String? url,
  }) async => content;
}
