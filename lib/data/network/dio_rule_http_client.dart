import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:dio/dio.dart';

/// 基于 Dio 的规则 HTTP 客户端：负责超时、重试、编码与状态码处理。
class DioRuleHttpClient implements ClosableRuleHttpClient {
  DioRuleHttpClient({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  final Dio _dio;

  @override
  Future<RuleHttpResponse> send(RuleHttpRequest request) async {
    final retries = request.retry < 0 ? 0 : (request.retry > 2 ? 2 : request.retry);
    DioException? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final headers = Map<String, String>.of(request.headers);
        if (request.body != null && !_hasHeader(headers, 'content-type')) {
          final body = request.body!.trimLeft();
          if (body.startsWith('{') || body.startsWith('[')) {
            headers['Content-Type'] = 'application/json; charset=utf-8';
          }
        }
        final response = await _dio.request<List<int>>(
          request.uri.toString(),
          data: request.body,
          options: Options(
            method: request.method,
            headers: headers,
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null,
            followRedirects: true,
            receiveTimeout: request.timeout,
            sendTimeout: request.timeout,
          ),
        );
        final statusCode = response.statusCode ?? 0;
        final body = _decode(
          response.data ?? const <int>[],
          request.encoding,
          response.headers.value(Headers.contentTypeHeader),
        );
        if (statusCode < 200 || statusCode >= 300) {
          throw NetworkException('请求失败：HTTP $statusCode ${request.uri}');
        }
        return RuleHttpResponse(
          statusCode: statusCode,
          body: body,
          uri: response.realUri,
          headers: <String, String>{
            for (final entry in response.headers.map.entries) entry.key: entry.value.join(', '),
          },
        );
      } on DioException catch (error) {
        lastError = error;
        if (attempt < retries) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    throw NetworkException(
      '网络请求失败：${request.uri}',
      cause: lastError,
      stackTrace: lastError?.stackTrace,
    );
  }

  @override
  Future<void> close() async => _dio.close(force: true);

  bool _hasHeader(Map<String, String> headers, String name) =>
      headers.keys.any((key) => key.toLowerCase() == name);

  String _decode(List<int> bytes, String encoding, String? contentType) {
    final normalized = encoding.trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'utf-8':
      case 'utf8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'latin-1':
      case 'latin1':
      case 'iso-8859-1':
        return latin1.decode(bytes);
      case 'ascii':
        return const AsciiCodec(allowInvalid: true).decode(bytes);
      default:
        final charset = RegExp(r'charset=([^;]+)').firstMatch(contentType ?? '')?.group(1)?.trim();
        if (charset != null && charset.toLowerCase() != normalized) {
          return _decode(bytes, charset, null);
        }
        throw UnsupportedCapabilityException('不支持的响应编码：$encoding');
    }
  }
}
