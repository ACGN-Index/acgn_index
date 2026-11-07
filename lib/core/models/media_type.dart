/// 内容类型：决定详情页与阅读器的形态。
enum MediaType {
  anime('anime'),
  comic('comic'),
  novel('novel');

  const MediaType(this.wireName);

  /// 规则 JSON 与数据库中的稳定标识，禁止重命名。
  final String wireName;

  static MediaType? tryParse(String? value) =>
      values.where((type) => type.wireName == value).firstOrNull;
}
