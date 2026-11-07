import 'dart:io';

import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConstants.appVersion 与 pubspec.yaml 保持一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml 缺少 version 字段');
    expect(match?.group(1), AppConstants.appVersion);
  });
}
