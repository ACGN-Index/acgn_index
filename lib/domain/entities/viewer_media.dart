/// 查看器所需的远程媒体：视频源、漫画图片等都以「地址 + 站点请求头」描述。
///
/// 请求头用于携带规则声明的 Referer / Cookie；记录日志前必须经 `AppLogger.redact`。
class ViewerMedia {
  const ViewerMedia({required this.uri, this.headers = const <String, String>{}});

  final Uri uri;
  final Map<String, String> headers;

  bool get hasHeaders => headers.isNotEmpty;
}
