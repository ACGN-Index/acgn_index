import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';

/// 规则来源：内置（随应用更新、只读）或用户导入。
enum RuleSourceOrigin {
  builtin('builtin'),
  imported('imported');

  const RuleSourceOrigin(this.wireName);

  final String wireName;

  static RuleSourceOrigin? tryParse(String? value) =>
      values.where((origin) => origin.wireName == value).firstOrNull;
}

/// 已安装的规则源：规则包本身 + 本地安装状态。
class RuleSource {
  const RuleSource({
    required this.pack,
    required this.enabled,
    required this.installedAt,
    this.origin = RuleSourceOrigin.imported,
    this.readOnly = false,
    this.priority = 0,
  });

  final RulePack pack;
  final bool enabled;
  final DateTime installedAt;
  final RuleSourceOrigin origin;

  /// 内置规则不可编辑，只可启用/停用或删除。
  final bool readOnly;

  /// 聚合排序权重，数值越小越靠前。
  final int priority;

  String get id => pack.meta.id;
  String get name => pack.meta.name;
  String get baseUrl => pack.meta.baseUrl;
  String get version => pack.meta.version;
  MediaType get type => pack.meta.type;
  String get notice => pack.meta.notice;

  bool get isBuiltin => origin == RuleSourceOrigin.builtin;

  RuleSource copyWith({bool? enabled}) => RuleSource(
    pack: pack,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt,
    origin: origin,
    readOnly: readOnly,
    priority: priority,
  );
}
