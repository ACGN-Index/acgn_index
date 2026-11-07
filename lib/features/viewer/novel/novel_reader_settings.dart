import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器配色。颜色用 int 表达，便于持久化并在绘制时还原。
enum NovelReaderTheme {
  paper(0xFFF7F2E8, 0xFF2B2B2B),
  sepia(0xFFEBDCBF, 0xFF4A3B2A),
  night(0xFF121212, 0xFFCFCFCF);

  const NovelReaderTheme(this.background, this.foreground);

  final int background;
  final int foreground;

  static NovelReaderTheme fromName(String? name) =>
      values.firstWhere((theme) => theme.name == name, orElse: () => NovelReaderTheme.paper);
}

/// 小说阅读设置：字号、行距与背景配色。
@immutable
class NovelReaderSettings {
  const NovelReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.theme = NovelReaderTheme.paper,
  });

  final double fontSize;
  final double lineHeight;
  final NovelReaderTheme theme;

  NovelReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    NovelReaderTheme? theme,
  }) => NovelReaderSettings(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    theme: theme ?? this.theme,
  );
}

/// 阅读设置持久化在 SharedPreferences，跨页面与重启保留。
final AsyncNotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>
novelReaderSettingsProvider =
    AsyncNotifierProvider<NovelReaderSettingsNotifier, NovelReaderSettings>(
      NovelReaderSettingsNotifier.new,
    );

class NovelReaderSettingsNotifier extends AsyncNotifier<NovelReaderSettings> {
  static const String _fontSizeKey = 'novel_reader_font_size';
  static const String _lineHeightKey = 'novel_reader_line_height';
  static const String _themeKey = 'novel_reader_theme';

  @override
  Future<NovelReaderSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return NovelReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 18,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.8,
      theme: NovelReaderTheme.fromName(prefs.getString(_themeKey)),
    );
  }

  Future<void> save(NovelReaderSettings settings) async {
    state = AsyncData<NovelReaderSettings>(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setString(_themeKey, settings.theme.name);
  }
}
