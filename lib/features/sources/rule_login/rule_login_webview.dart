import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 登录页内嵌 WebView；把控制器、页面地址与进度变化交给页面处理。
class RuleLoginWebView extends StatelessWidget {
  const RuleLoginWebView({
    required this.initialUrl,
    required this.headers,
    required this.onCreated,
    required this.onUrlChanged,
    this.userAgent,
    this.onProgress,
    this.onLoadError,
    super.key,
  });

  final Uri initialUrl;
  final Map<String, String> headers;
  final ValueChanged<InAppWebViewController> onCreated;
  final ValueChanged<Uri> onUrlChanged;
  final String? userAgent;
  final ValueChanged<int>? onProgress;
  final ValueChanged<String>? onLoadError;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(initialUrl.toString()),
        headers: headers,
      ),
      initialSettings: InAppWebViewSettings(userAgent: userAgent),
      onWebViewCreated: onCreated,
      onProgressChanged: (controller, progress) => onProgress?.call(progress),
      onLoadStop: (controller, url) => _notifyUrl(url, onUrlChanged),
      onUpdateVisitedHistory: (controller, url, isReload) => _notifyUrl(url, onUrlChanged),
      onReceivedError: (controller, request, error) {
        final description = error.description;
        if (description.isNotEmpty) {
          onLoadError?.call(description);
        }
      },
    );
  }

  void _notifyUrl(WebUri? url, ValueChanged<Uri> callback) {
    if (url == null) {
      return;
    }
    final parsed = Uri.tryParse(url.toString());
    if (parsed != null) {
      callback(parsed);
    }
  }
}
