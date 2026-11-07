/// 校验结果的严重程度。
enum RuleIssueSeverity {
  /// 规则不可用，必须修复。
  error,

  /// 不影响当前版本运行，但可能是笔误或为未来版本预留。
  warning,
}

/// 单条校验问题。[path] 指向 JSON 内的位置，便于规则编辑器定位。
class RuleIssue {
  const RuleIssue({
    required this.path,
    required this.message,
    this.severity = RuleIssueSeverity.error,
  });

  final String path;
  final String message;
  final RuleIssueSeverity severity;

  @override
  String toString() => '${severity.name} @ $path: $message';
}

/// 规则包校验结果。[isValid] 只取决于是否存在 error 级问题。
class ValidationResult {
  const ValidationResult(this.issues);

  const ValidationResult.valid() : issues = const <RuleIssue>[];

  final List<RuleIssue> issues;

  bool get isValid => errors.isEmpty;

  Iterable<RuleIssue> get errors =>
      issues.where((issue) => issue.severity == RuleIssueSeverity.error);

  Iterable<RuleIssue> get warnings =>
      issues.where((issue) => issue.severity == RuleIssueSeverity.warning);
}
