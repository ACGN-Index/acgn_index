import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';

/// 已安装的规则源：规则包本身 + 本地安装状态。
class RuleSource {
  const RuleSource({required this.pack, required this.enabled, required this.installedAt});

  final RulePack pack;
  final bool enabled;
  final DateTime installedAt;

  String get id => pack.meta.id;
  String get name => pack.meta.name;
  String get baseUrl => pack.meta.baseUrl;
  String get version => pack.meta.version;
  Set<MediaType> get types => pack.meta.types;

  RuleSource copyWith({bool? enabled}) => RuleSource(
    pack: pack,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt,
  );
}
