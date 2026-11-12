import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/features/sources/rule_login/rule_login_providers.dart';
import 'package:acgn_index/features/sources/rule_login_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sources_test_helpers.dart';

void main() {
  late FakeRuleAuthRepository authRepository;

  setUp(() => authRepository = FakeRuleAuthRepository());

  tearDown(() => authRepository.close());

  RulePack buildPack({RuleLoginRule? login}) => RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: const RuleMeta(
      id: 'rule.test',
      name: '测试规则',
      type: MediaType.comic,
      baseUrl: 'https://example.invalid',
      version: '1.0.0',
      author: 'tester',
      lang: 'zh',
    ),
    login: login,
  );

  Future<void> pumpPage(WidgetTester tester, RulePack pack) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ruleAuthRepositoryProvider.overrideWithValue(authRepository),
          ruleLoginWebViewSupportedProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RuleLoginPage(pack: pack),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('手动请求头模式可以保存 Cookie', (tester) async {
    await pumpPage(
      tester,
      buildPack(
        login: const RuleLoginRule(mode: RuleLoginMode.headers),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('login.cookies')),
      'token=abc; sid=1',
    );
    await tester.tap(find.text('保存登录状态'));
    await tester.pumpAndSettle();

    final auth = authRepository.auths['rule.test'];
    expect(auth, isNotNull);
    expect(auth!.cookies, <String, String>{'token': 'abc', 'sid': '1'});
  });

  testWidgets('已登录时可以清除本地凭据', (tester) async {
    await authRepository.save(
      RuleAuth(
        ruleId: 'rule.test',
        cookies: const <String, String>{'sid': '1'},
        updatedAt: DateTime(2026),
      ),
    );
    await pumpPage(
      tester,
      buildPack(
        login: const RuleLoginRule(mode: RuleLoginMode.headers),
      ),
    );

    await tester.tap(find.text('清除登录状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();

    expect(authRepository.auths, isEmpty);
  });

  testWidgets('规则没有登录配置时展示提示', (tester) async {
    await pumpPage(tester, buildPack());

    expect(find.text('该规则没有登录配置。'), findsOneWidget);
  });

  testWidgets('WebView 不可用时提示手动填写', (tester) async {
    await pumpPage(
      tester,
      buildPack(
        login: const RuleLoginRule(url: '/login'),
      ),
    );

    expect(find.textContaining('无法使用内置 WebView'), findsOneWidget);
  });
}
