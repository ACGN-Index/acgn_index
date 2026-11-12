import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_config.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_controller.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 弹幕库索引面板：搜索作品、挑选集数并拉取弹幕。
///
/// 关闭时返回已拉取的弹幕列表（可能为空），由播放器页面应用。
class DanmakuLibrarySheet extends ConsumerStatefulWidget {
  const DanmakuLibrarySheet({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  ConsumerState<DanmakuLibrarySheet> createState() => _DanmakuLibrarySheetState();
}

class _DanmakuLibrarySheetState extends ConsumerState<DanmakuLibrarySheet> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  final TextEditingController _baseUrl = TextEditingController();
  final TextEditingController _appId = TextEditingController();
  final TextEditingController _appSecret = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _query.dispose();
    _baseUrl.dispose();
    _appId.dispose();
    _appSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(danmakuLibraryConfigProvider).value;
    final state = ref.watch(danmakuLibraryProvider);
    if (config != null && !_prefilled) {
      _prefilled = true;
      _baseUrl.text = config.baseUrl;
      _appId.text = config.appId;
      _appSecret.text = config.appSecret;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.viewerDanmakuLibrary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (state.isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.viewerDanmakuLibraryRequestFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (config != null && !config.canQuery) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.viewerDanmakuLibraryNotConfigured,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: l10n.viewerDanmakuLibrarySearchHint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.isLoading ? null : _search,
                  child: Text(l10n.viewerDanmakuLibrarySearch),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.status == DanmakuLibraryStatus.loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.viewerDanmakuLibraryLoading,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else if (state.status == DanmakuLibraryStatus.ready && state.animes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.viewerDanmakuLibraryEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final anime in state.animes)
                    ExpansionTile(
                      key: ValueKey<int>(anime.animeId),
                      tilePadding: EdgeInsets.zero,
                      title: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        <String>[
                          if (anime.typeLabel.isNotEmpty) anime.typeLabel,
                          l10n.viewerDanmakuLibraryEpisodeCount(anime.episodes.length),
                        ].join(' · '),
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final episode in anime.episodes)
                              ActionChip(
                                label: Text(episode.title),
                                onPressed: state.isLoading
                                    ? null
                                    : () => _applyEpisode(anime, episode),
                              ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.viewerDanmakuLibraryConfig),
                    initiallyExpanded: config != null && !config.hasCredentials,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.viewerDanmakuLibraryNotConfigured,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextField(
                        controller: _baseUrl,
                        decoration: InputDecoration(
                          labelText: l10n.viewerDanmakuLibraryBaseUrl,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _appId,
                        decoration: InputDecoration(
                          labelText: l10n.viewerDanmakuLibraryAppId,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _appSecret,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.viewerDanmakuLibraryAppSecret,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: _saveConfig,
                          child: Text(l10n.viewerDanmakuLibrarySave),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    await ref
        .read(danmakuLibraryConfigProvider.notifier)
        .save(
          DanmakuLibraryConfig(
            baseUrl: _baseUrl.text.trim().isEmpty
                ? DanmakuLibraryConfig.defaultBaseUrl
                : _baseUrl.text.trim(),
            appId: _appId.text,
            appSecret: _appSecret.text,
          ),
        );
  }

  Future<void> _search() async {
    final config = ref.read(danmakuLibraryConfigProvider).value;
    if (config == null || !config.canQuery) {
      await _saveConfig();
    }
    await ref.read(danmakuLibraryProvider.notifier).search(_query.text);
  }

  Future<void> _applyEpisode(
    DanmakuLibraryAnime anime,
    DanmakuLibraryEpisode episode,
  ) async {
    final comments = await ref.read(danmakuLibraryProvider.notifier).useEpisode(anime, episode);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop<List<DanmakuComment>>(comments);
  }
}
