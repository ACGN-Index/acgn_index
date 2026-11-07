import 'package:flutter/material.dart';

/// 应用主题：Material 3 + 单一品牌色，亮/暗色成对提供。
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF5B5FD6);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);
    final labelStyle =
        ThemeData(colorScheme: colorScheme).textTheme.labelMedium ?? const TextStyle();
    final selectedLabelStyle = labelStyle.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final unselectedLabelStyle = labelStyle.copyWith(color: colorScheme.onSurfaceVariant);

    return ThemeData(
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
      // 底部导航与侧边导航共用同一套视觉令牌，形态切换时风格保持一致。
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? selectedLabelStyle : unselectedLabelStyle,
        ),
        height: 74,
      ),
      navigationRailTheme: NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 0,
        selectedLabelTextStyle: selectedLabelStyle,
        unselectedLabelTextStyle: unselectedLabelStyle,
        minWidth: 80,
      ),
    );
  }
}
