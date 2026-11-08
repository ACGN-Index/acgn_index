import 'package:acgn_index/rule_engine/models/capability_rule.dart';

/// 正文中的远程素材（图片、视频、文件）及其请求头。
class ContentMedia {
  const ContentMedia({
    required this.uri,
    this.headers = const <String, String>{},
  });

  final Uri uri;
  final Map<String, String> headers;
}

/// `content` 能力求值结果的公共部分。
sealed class RuleContent {
  const RuleContent({
    required this.title,
    this.headers = const <String, String>{},
    this.fields = const <String, Object?>{},
  });

  final String title;

  /// 加载图片 / 视频 / 文件时需要携带的请求头。
  final Map<String, String> headers;

  /// 规则声明的原始求值结果。
  final Map<String, Object?> fields;

  ContentMode get mode;
}

/// 漫画图片列表。
final class ImagesContent extends RuleContent {
  const ImagesContent({
    required super.title,
    required this.images,
    super.headers,
    super.fields,
  });

  final List<ContentMedia> images;

  @override
  ContentMode get mode => ContentMode.images;
}

/// 小说正文与可选插图。
final class TextContent extends RuleContent {
  const TextContent({
    required super.title,
    required this.paragraphs,
    this.images = const <ContentMedia>[],
    super.headers,
    super.fields,
  });

  final List<String> paragraphs;
  final List<ContentMedia> images;

  @override
  ContentMode get mode => ContentMode.text;
}

/// 视频线路。
class VideoSource {
  const VideoSource({required this.uri, this.type, this.quality});

  final Uri uri;

  /// `hls` / `mp4` 等；规则未声明时为 null。
  final String? type;

  final String? quality;
}

/// 视频播放源与弹幕地址。
final class VideoContent extends RuleContent {
  const VideoContent({
    required super.title,
    required this.sources,
    this.danmakuUrl,
    super.headers,
    super.fields,
  });

  final List<VideoSource> sources;
  final Uri? danmakuUrl;

  @override
  ContentMode get mode => ContentMode.video;
}

/// 可下载文件（如 EPUB / TXT）。
final class FileContent extends RuleContent {
  const FileContent({
    required super.title,
    required this.url,
    required this.format,
    this.size,
    this.checksum,
    super.headers,
    super.fields,
  });

  final Uri url;
  final String format;
  final int? size;
  final String? checksum;

  @override
  ContentMode get mode => ContentMode.file;
}
