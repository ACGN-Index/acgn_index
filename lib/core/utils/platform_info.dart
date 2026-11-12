import 'dart:io';

/// 是否运行在桌面平台（Windows / Linux / macOS）。
bool get isDesktopPlatform => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
