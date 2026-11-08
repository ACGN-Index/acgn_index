import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/utils/html_text.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_content.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_fetch.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_request_builder.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_values.dart';

/// 正文服务抽象，便于详情页测试替换。
abstract interface class RuleContentService {
  Future<RuleContent> fetch(
    RulePack pack, {
    required String id,
    required TocEntry chapter,
    String? url,
  });
}

/// 执行规则包的 `content` 能力。
class RuleContentPipeline implements RuleContentService {
  const RuleContentPipeline({
    required this.httpClient,
    this.evaluator = const FieldEvaluator(),
    this.requestBuilder = const RuleRequestBuilder(),
  });

  final RuleHttpClient httpClient;
  final FieldEvaluator evaluator;
  final RuleRequestBuilder requestBuilder;

  @override
  Future<RuleContent> fetch(
    RulePack pack, {
    required String id,
    required TocEntry chapter,
    String? url,
  }) async {
    final capability = pack.capabilities[RuleCapability.content];
    if (capability is! ContentCapabilityRule) {
      throw const UnsupportedCapabilityException('规则未声明 content 能力');
    }
    final mode = capability.mode;
    if (mode == null) {
      throw const RuleFormatException('content 缺少 mode');
    }
    final variables = _contentVariables(pack, id, url, chapter);
    if (capability.url.trim().isEmpty) {
      // 目录条目自带播放地址：不发请求，直接由字段构造视频源。
      if (mode != ContentMode.video) {
        throw const RuleFormatException('content 缺少 url');
      }
      return _buildInlineVideo(pack, capability, chapter, variables);
    }
    final resolvedVariables = await _resolveVariables(pack, capability, variables);
    final request = requestBuilder.build(
      pack: pack,
      url: capability.url,
      method: capability.method,
      body: capability.body,
      headers: capability.headers,
      variables: resolvedVariables,
    );
    if (mode == ContentMode.file) {
      return _buildFile(pack, capability, chapter, request, resolvedVariables);
    }
    final document = await fetchRuleDocument(httpClient, request);
    final context = RuleEvalContext(
      pack: pack,
      pageUri: document.uri,
      json: document.json,
      htmlDocument: document.htmlDocument,
      xmlNode: document.xmlDocument,
      variables: resolvedVariables,
    );
    final fields = _evaluateFields(capability.fields, context);
    final headers = mediaHeaders(
      pack,
      capability,
      pageUri: document.uri,
      referer: scalarValue(fields['referer']),
    );
    final title = scalarValue(fields['title']) ?? chapter.title;
    return switch (mode) {
      ContentMode.images => _buildImages(title, fields, document.uri, headers),
      ContentMode.text => _buildText(title, fields, document.uri, headers, chapter),
      ContentMode.video => _buildVideo(title, fields, document.uri, headers),
      ContentMode.file => throw const RuleFormatException('content.mode 非法'),
    };
  }

  /// `content.url` 为空时使用：页面基准地址取 `baseUrl`，只跑字段求值。
  RuleContent _buildInlineVideo(
    RulePack pack,
    ContentCapabilityRule capability,
    TocEntry chapter,
    Map<String, Object?> variables,
  ) {
    final pageUri = Uri.parse(pack.meta.baseUrl);
    final context = RuleEvalContext(pack: pack, pageUri: pageUri, variables: variables);
    final fields = _evaluateFields(capability.fields, context);
    final headers = mediaHeaders(
      pack,
      capability,
      pageUri: pageUri,
      referer: scalarValue(fields['referer']),
    );
    return _buildVideo(
      scalarValue(fields['title']) ?? chapter.title,
      fields,
      pageUri,
      headers,
    );
  }

  Future<Map<String, Object?>> _resolveVariables(
    RulePack pack,
    ContentCapabilityRule capability,
    Map<String, Object?> variables,
  ) async {
    final resolve = capability.resolve;
    if (resolve == null) {
      return variables;
    }
    final request = requestBuilder.build(
      pack: pack,
      url: resolve.url,
      method: resolve.method,
      body: resolve.body,
      headers: capability.headers,
      variables: variables,
    );
    final document = await fetchRuleDocument(httpClient, request);
    final context = RuleEvalContext(
      pack: pack,
      pageUri: document.uri,
      json: document.json,
      htmlDocument: document.htmlDocument,
      xmlNode: document.xmlDocument,
      variables: variables,
    );
    final fields = _evaluateFields(resolve.fields, context);
    return <String, Object?>{
      ...variables,
      for (final entry in fields.entries) 'resolve.${entry.key}': scalarValue(entry.value) ?? '',
    };
  }

  RuleContent _buildFile(
    RulePack pack,
    ContentCapabilityRule capability,
    TocEntry chapter,
    RuleHttpRequest request,
    Map<String, Object?> variables,
  ) {
    final context = RuleEvalContext(
      pack: pack,
      pageUri: request.uri,
      variables: variables,
    );
    final fields = _evaluateFields(capability.fields, context);
    final format = scalarValue(fields['format']);
    if (format == null) {
      throw const RuleFormatException('content.file 缺少 format 字段');
    }
    return FileContent(
      title: scalarValue(fields['title']) ?? chapter.title,
      url: request.uri,
      format: format,
      size: intValue(fields['size']),
      checksum: scalarValue(fields['checksum']),
      headers: mediaHeaders(
        pack,
        capability,
        pageUri: request.uri,
        referer: scalarValue(fields['referer']),
      ),
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  ImagesContent _buildImages(
    String title,
    Map<String, Object?> fields,
    Uri pageUri,
    Map<String, String> headers,
  ) {
    if (!fields.containsKey('images')) {
      throw const RuleFormatException('content.images 缺少 images 字段');
    }
    return ImagesContent(
      title: title,
      images: _mediaList(fields['images'], pageUri, headers),
      headers: headers,
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  TextContent _buildText(
    String title,
    Map<String, Object?> fields,
    Uri pageUri,
    Map<String, String> headers,
    TocEntry chapter,
  ) {
    final paragraphs = <String>[
      for (final paragraph in stringValues(fields['paragraphs'])) ...htmlToParagraphs(paragraph),
    ];
    if (paragraphs.isEmpty) {
      if (!fields.containsKey('body') && !fields.containsKey('paragraphs')) {
        throw const RuleFormatException('content.text 缺少 body / paragraphs 字段');
      }
      final body = scalarValue(fields['body']);
      if (body != null) {
        paragraphs.addAll(htmlToParagraphs(body));
      }
    }
    return TextContent(
      title: scalarValue(fields['title']) ?? chapter.title,
      paragraphs: List<String>.unmodifiable(paragraphs),
      images: _mediaList(fields['images'], pageUri, headers),
      headers: headers,
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  VideoContent _buildVideo(
    String title,
    Map<String, Object?> fields,
    Uri pageUri,
    Map<String, String> headers,
  ) {
    var urls = stringValues(fields['urls']);
    if (urls.isEmpty) {
      urls = stringValues(fields['url']);
    }
    if (urls.isEmpty) {
      throw const RuleFormatException('content.video 缺少 url / urls 字段');
    }
    final types = stringValues(fields['type']);
    final qualities = stringValues(fields['quality']);
    final sources = <VideoSource>[];
    for (var index = 0; index < urls.length; index++) {
      final uri = absoluteUri(pageUri, urls[index]);
      if (uri == null) {
        continue;
      }
      sources.add(
        VideoSource(
          uri: uri,
          type: types.isEmpty ? null : types[index < types.length ? index : 0],
          quality: qualities.isEmpty ? null : qualities[index < qualities.length ? index : 0],
        ),
      );
    }
    if (sources.isEmpty) {
      throw const RuleFormatException('content.video 没有可用地址');
    }
    return VideoContent(
      title: title,
      sources: List<VideoSource>.unmodifiable(sources),
      danmakuUrl: absoluteUri(pageUri, scalarValue(fields['danmakuUrl'])),
      headers: headers,
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  List<ContentMedia> _mediaList(
    Object? value,
    Uri pageUri,
    Map<String, String> headers,
  ) {
    final result = <ContentMedia>[];
    for (final item in stringValues(value)) {
      final uri = absoluteUri(pageUri, item);
      if (uri != null) {
        result.add(ContentMedia(uri: uri, headers: headers));
      }
    }
    return List<ContentMedia>.unmodifiable(result);
  }

  Map<String, Object?> _evaluateFields(
    Map<String, FieldRule> fields,
    RuleEvalContext context,
  ) {
    final values = <String, Object?>{};
    for (final entry in fields.entries) {
      values[entry.key] = evaluator.evaluate(entry.value, context);
    }
    return values;
  }

  Map<String, Object?> _contentVariables(
    RulePack pack,
    String id,
    String? url,
    TocEntry chapter,
  ) {
    final variables = <String, Object?>{
      'baseUrl': pack.meta.baseUrl,
      'id': id,
      'url': url ?? '',
      'chapter.id': chapter.id ?? '',
      'chapter.url': chapter.url ?? '',
      'chapter.title': chapter.title,
    };
    for (final entry in chapter.extra.entries) {
      variables['chapter.${entry.key}'] = entry.value;
    }
    variables['chapter.id'] = chapter.id ?? scalarValue(chapter.extra['id']) ?? '';
    variables['chapter.url'] = chapter.url ?? '';
    variables['chapter.title'] = chapter.title;
    if (chapter.group != null) {
      variables['chapter.group'] = chapter.group;
    }
    if (chapter.groupTitle != null) {
      variables['chapter.groupTitle'] = chapter.groupTitle;
    }
    return variables;
  }
}
