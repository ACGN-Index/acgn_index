import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

/// 已解析的响应文档：JSON、HTML、XML 三选一。
class RuleDocument {
  const RuleDocument({
    required this.uri,
    this.json,
    this.htmlDocument,
    this.xmlDocument,
  });

  factory RuleDocument.parse(
    String body, {
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
  }) {
    final contentType = _header(headers, 'content-type').toLowerCase();
    final trimmed = body.trimLeft();
    final looksJson = trimmed.startsWith('{') || trimmed.startsWith('[');
    final looksXml = trimmed.startsWith('<?xml') || contentType.contains('xml');
    final looksHtml = trimmed.startsWith('<') || contentType.contains('html');

    if (contentType.contains('json') || looksJson) {
      try {
        return RuleDocument(uri: uri, json: jsonDecode(body));
      } on FormatException catch (error) {
        throw RuleFormatException('响应不是合法 JSON：${error.message}', cause: error);
      }
    }
    if (looksXml) {
      try {
        return RuleDocument(uri: uri, xmlDocument: xml.XmlDocument.parse(body));
      } on xml.XmlException catch (error) {
        throw RuleFormatException('响应不是合法 XML：${error.message}', cause: error);
      }
    }
    if (looksHtml) {
      return RuleDocument(uri: uri, htmlDocument: html_parser.parse(body));
    }
    try {
      return RuleDocument(uri: uri, json: jsonDecode(body));
    } on FormatException {
      return RuleDocument(uri: uri, htmlDocument: html_parser.parse(body));
    }
  }

  final Uri uri;
  final Object? json;
  final dom.Document? htmlDocument;
  final xml.XmlDocument? xmlDocument;

  static String _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        return entry.value;
      }
    }
    return '';
  }
}
