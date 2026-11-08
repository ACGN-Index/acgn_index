import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_fetch.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_request_builder.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_values.dart';
import 'package:acgn_index/rule_engine/pipeline/template_renderer.dart';

/// 详情服务抽象，便于详情页测试替换。
abstract interface class RuleDetailService {
  Future<WorkDetail> fetch(RulePack pack, {required String id, String? url});
}

/// 执行规则包的 `detail` 能力。
class RuleDetailPipeline implements RuleDetailService {
  const RuleDetailPipeline({
    required this.httpClient,
    this.evaluator = const FieldEvaluator(),
    this.requestBuilder = const RuleRequestBuilder(),
  });

  final RuleHttpClient httpClient;
  final FieldEvaluator evaluator;
  final RuleRequestBuilder requestBuilder;

  @override
  Future<WorkDetail> fetch(RulePack pack, {required String id, String? url}) async {
    final capability = pack.capabilities[RuleCapability.detail];
    if (capability is! DetailCapabilityRule) {
      throw const UnsupportedCapabilityException('规则未声明 detail 能力');
    }
    final variables = <String, Object?>{
      'baseUrl': pack.meta.baseUrl,
      'id': id,
      'url': url ?? '',
    };
    final detailUrl = url == null || url.isEmpty
        ? _absoluteUrl(pack, renderTemplate(capability.url, variables))
        : url;
    variables['url'] = detailUrl;
    final request = requestBuilder.build(
      pack: pack,
      url: capability.url,
      method: capability.method,
      body: capability.body,
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
    final fields = <String, Object?>{};
    for (final entry in capability.fields.entries) {
      fields[entry.key] = evaluator.evaluate(entry.value, context);
    }
    final title = scalarValue(fields['title']);
    if (title == null) {
      throw const RuleFormatException('detail 缺少 title 字段');
    }
    return WorkDetail(
      title: title,
      url: detailUrl,
      headers: mediaHeaders(pack, capability, pageUri: document.uri),
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  String _absoluteUrl(RulePack pack, String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return value;
    }
    return Uri.parse(pack.meta.baseUrl).resolveUri(parsed ?? Uri()).toString();
  }
}
