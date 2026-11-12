import 'dart:async';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/cookie_utils.dart';
import 'package:acgn_index/data/network/webview_cookie_store.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/features/sources/rule_editor/editor_controls.dart';
import 'package:acgn_index/features/sources/rule_login/rule_login_providers.dart';
import 'package:acgn_index/features/sources/rule_login/rule_login_webview.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_request_builder.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 规则登录：WebView 网页登录抓取 Cookie，或手动填写 Cookie / 请求头。
///
/// 登录结果按 `pack.meta.id` 保存在本地，返回后自动附加到该规则的所有请求。
class RuleLoginPage extends ConsumerStatefulWidget {
  const RuleLoginPage({this.pack, super.key});

  final RulePack? pack;

  @override
  ConsumerState<RuleLoginPage> createState() => _RuleLoginPageState();
}

class _RuleLoginPageState extends ConsumerState<RuleLoginPage> {
  final TextEditingController _cookieController = TextEditingController();

  Map<String, String> _headers = const <String, String>{};
  Map<String, String> _cookies = const <String, String>{};
  InAppWebViewController? _webController;
  Uri? _loginUri;
  int _progress = 100;
  String? _loadError;
  bool _loading = true;
  bool _saving = false;
  bool _hasSavedAuth = false;
  bool _successDetected = false;
  int _authRevision = 0;

  RulePack? get _pack => widget.pack;
  RuleLoginRule? get _login => _pack?.login;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedAuth());
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAuth() async {
    final pack = _pack;
    if (pack == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final auth = await ref.read(ruleAuthRepositoryProvider).find(pack.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cookies = Map<String, String>.of(auth?.cookies ?? const <String, String>{});
        _headers = Map<String, String>.of(
          auth?.headers ?? _defaultAuthHeaders(pack),
        );
        _cookieController.text = formatCookieHeader(_cookies);
        _hasSavedAuth = auth != null && !auth.isEmpty;
        _loginUri = _resolveLoginUri(pack);
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-login').severe('读取登录凭据失败', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Map<String, String> _defaultAuthHeaders(RulePack pack) => <String, String>{
    for (final entry in pack.login?.headers.entries ?? const <MapEntry<String, String>>[])
      if (entry.key.trim().isNotEmpty) entry.key: entry.value,
  };

  Uri? _resolveLoginUri(RulePack pack) {
    final login = pack.login;
    if (login == null || !login.hasUrl) {
      return null;
    }
    final resolved = Uri.tryParse(login.resolveUrl(pack.meta.baseUrl));
    if (resolved == null ||
        resolved.host.isEmpty ||
        (resolved.scheme != 'http' && resolved.scheme != 'https') ||
        !isHostAllowed(pack, resolved.host)) {
      return null;
    }
    return resolved;
  }

  Future<void> _captureCookies() async {
    final controller = _webController;
    final uri = _loginUri;
    final login = _login;
    if (controller == null || uri == null || login == null) {
      return;
    }
    final captured = await WebViewCookieStore.read(uri, controller: controller);
    final names = login.cookieNames;
    final filtered = <String, String>{};
    if (names.isEmpty) {
      filtered.addAll(captured);
    } else {
      for (final name in names) {
        final value = captured[name];
        if (value != null) {
          filtered[name] = value;
        }
      }
    }
    if (filtered.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _cookies = <String, String>{..._cookies, ...filtered};
      _cookieController.text = formatCookieHeader(_cookies);
    });
  }

  void _onUrlChanged(Uri url) {
    final login = _login;
    if (login == null || _successDetected) {
      return;
    }
    if (login.matchesSuccess(url.toString())) {
      setState(() => _successDetected = true);
      unawaited(_captureCookies());
    }
  }

  Future<void> _save() async {
    final pack = _pack;
    if (pack == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      if (_login?.mode == RuleLoginMode.webview) {
        await _captureCookies();
      }
      final cookies = parseCookieHeader(_cookieController.text);
      final headers = <String, String>{
        for (final entry in _headers.entries)
          if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
            entry.key.trim(): entry.value,
      };
      if (cookies.isEmpty && headers.isEmpty) {
        _showMessage(l10n.ruleLoginEmpty);
        return;
      }
      await ref
          .read(ruleAuthRepositoryProvider)
          .save(
            RuleAuth(
              ruleId: pack.id,
              cookies: cookies,
              headers: headers,
              updatedAt: DateTime.now(),
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() => _hasSavedAuth = true);
      _showMessage(l10n.ruleLoginSaved);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-login').severe('保存登录凭据失败', error, stackTrace);
      if (mounted) {
        _showMessage(l10n.ruleLoginSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _clear() async {
    final pack = _pack;
    if (pack == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ruleLoginClearTitle),
        content: Text(l10n.ruleLoginClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ruleEditorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ruleLoginClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(ruleAuthRepositoryProvider).delete(pack.id);
      if (ref.read(ruleLoginWebViewSupportedProvider)) {
        final uri = _loginUri ?? Uri.tryParse(pack.meta.baseUrl);
        if (uri != null) {
          await WebViewCookieStore.clear(uri);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _cookies = const <String, String>{};
        _headers = _defaultAuthHeaders(pack);
        _cookieController.clear();
        _hasSavedAuth = false;
        _successDetected = false;
        _authRevision++;
      });
      _showMessage(l10n.ruleLoginCleared);
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-login').severe('清除登录凭据失败', error, stackTrace);
      if (mounted) {
        _showMessage(l10n.ruleLoginSaveFailed);
      }
    }
  }

  void _refresh() {
    final controller = _webController;
    if (controller == null) {
      return;
    }
    setState(() => _loadError = null);
    unawaited(controller.reload());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pack = _pack;
    if (pack == null) {
      return _messageScaffold(context, l10n.ruleLoginMissingPack);
    }
    final login = pack.login;
    if (login == null) {
      return _messageScaffold(context, l10n.ruleLoginNoConfig);
    }
    final webViewSupported = ref.watch(ruleLoginWebViewSupportedProvider);
    final useWebView = login.mode == RuleLoginMode.webview;
    final loginUri = _loginUri;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ruleLoginTitle(pack.name)),
        actions: <Widget>[
          if (useWebView && webViewSupported)
            IconButton(
              onPressed: _refresh,
              tooltip: l10n.ruleLoginRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                if (useWebView)
                  ..._webViewArea(
                    context: context,
                    l10n: l10n,
                    supported: webViewSupported,
                    loginUri: loginUri,
                  )
                else
                  _hintCard(
                    context,
                    icon: Icons.key_outlined,
                    text: l10n.ruleLoginHeadersModeHint,
                  ),
                if (_successDetected) ...<Widget>[
                  const SizedBox(height: 12),
                  _hintCard(
                    context,
                    icon: Icons.check_circle_outline,
                    text: l10n.ruleLoginSuccessDetected,
                  ),
                ],
                if (_loadError != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _hintCard(
                    context,
                    icon: Icons.error_outline,
                    text: l10n.ruleLoginLoadFailed(_loadError!),
                  ),
                ],
                const SizedBox(height: 16),
                _manualPanel(
                  l10n,
                  expanded: !useWebView || !webViewSupported || loginUri == null,
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              if (_hasSavedAuth)
                TextButton.icon(
                  onPressed: _loading || _saving ? null : _clear,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.ruleLoginClear),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading || _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(l10n.ruleLoginSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _webViewArea({
    required BuildContext context,
    required AppLocalizations l10n,
    required bool supported,
    required Uri? loginUri,
  }) {
    if (!supported) {
      return <Widget>[
        _hintCard(
          context,
          icon: Icons.desktop_access_disabled_outlined,
          text: l10n.ruleLoginWebViewUnsupported,
        ),
      ];
    }
    if (loginUri == null) {
      return <Widget>[
        _hintCard(
          context,
          icon: Icons.link_off,
          text: l10n.ruleLoginMissingUrl,
        ),
      ];
    }
    final height = (MediaQuery.sizeOf(context).height * 0.55).clamp(320.0, 720.0).toDouble();
    return <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          child: RuleLoginWebView(
            initialUrl: loginUri,
            headers: _webViewHeaders(_pack!),
            userAgent: _userAgent(_pack!),
            onCreated: (controller) => _webController = controller,
            onUrlChanged: _onUrlChanged,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _progress = progress);
              }
            },
            onLoadError: (message) {
              if (mounted) {
                setState(() => _loadError = message);
              }
            },
          ),
        ),
      ),
      if (_progress < 100) ...<Widget>[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _progress / 100),
      ],
    ];
  }

  Map<String, String> _webViewHeaders(RulePack pack) => RuleAuth(
    ruleId: pack.id,
    cookies: parseCookieHeader(_cookieController.text),
    headers: _headers,
    updatedAt: DateTime.now(),
  ).toRequestHeaders();

  String? _userAgent(RulePack pack) {
    for (final entry in pack.request.headers.entries) {
      if (entry.key.toLowerCase() == 'user-agent' && entry.value.trim().isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  Widget _manualPanel(AppLocalizations l10n, {required bool expanded}) {
    return Card(
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        title: Text(l10n.ruleLoginManualTitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('login.cookies'),
            controller: _cookieController,
            maxLines: 3,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.ruleLoginCookies,
              hintText: l10n.ruleLoginCookiesHint,
              helperText: l10n.ruleLoginCookiesHelp,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          EditorStringMapField(
            key: ValueKey<String>('login.headers.$_authRevision'),
            label: l10n.ruleLoginHeaders,
            helper: l10n.ruleLoginHeadersHelp,
            addLabel: l10n.ruleAddHeader,
            keyLabel: l10n.ruleHeaderName,
            valueLabel: l10n.ruleHeaderValue,
            value: _headers,
            onChanged: (values) => _headers = values,
          ),
        ],
      ),
    );
  }

  Widget _hintCard(BuildContext context, {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }

  Widget _messageScaffold(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleLoginTitle(_pack?.name ?? ''))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
