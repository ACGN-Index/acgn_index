/// 弹幕显示方式，与 B 站/弹弹play 的常见模式对齐。
enum DanmakuMode {
  scroll('scroll'),
  top('top'),
  bottom('bottom');

  const DanmakuMode(this.wireName);

  /// 规则 JSON 中的稳定标识，禁止重命名。
  final String wireName;

  static DanmakuMode tryParse(String? value) =>
      values.where((mode) => mode.wireName == value).firstOrNull ?? DanmakuMode.scroll;
}

/// 一条弹幕。[position] 是相对视频开头的出现时间。
class DanmakuComment {
  const DanmakuComment({
    required this.position,
    required this.text,
    this.mode = DanmakuMode.scroll,
    this.color = 0xFFFFFFFF,
    this.bold = false,
  }) : assert(text.length > 0, '弹幕内容不能为空');

  final Duration position;
  final String text;
  final DanmakuMode mode;

  /// ARGB 颜色。放在 domain 里用 int 表达，避免依赖 Flutter。
  final int color;
  final bool bold;
}
