import 'dart:async';

import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/features/viewer/novel/novel_reader_settings.dart';
import 'package:acgn_index/features/viewer/novel/novel_settings_sheet.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_message_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 小说查看器：分段正文 + 章节切换 + 可持久化的阅读设置与进度。
class NovelViewerPage extends ConsumerStatefulWidget {
  const NovelViewerPage({this.content, super.key});

  final NovelViewerContent? content;

  @override
  ConsumerState<NovelViewerPage> createState() => _NovelViewerPageState();
}

class _NovelViewerPageState extends ConsumerState<NovelViewerPage> {
  static const String _progressPrefix = 'novel_progress';
  static const Duration _saveDelay = Duration(milliseconds: 600);

  final ScrollController _scrollController = ScrollController();
  Timer? _saveTimer;
  int _chapterIndex = 0;
  bool _chromeVisible = true;

  NovelViewerContent? get _content => widget.content;

  NovelChapter? get _chapter {
    final content = _content;
    if (content == null || content.chapters.isEmpty) {
      return null;
    }
    return content.chapters[_chapterIndex];
  }

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    if (content == null || content.chapters.isEmpty) {
      return;
    }
    _chapterIndex = content.safeInitialChapterIndex;
    _scrollController.addListener(_handleScroll);
    unawaited(_restoreProgress());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_saveProgress());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final chapter = _chapter;
    if (content == null || chapter == null) {
      return ViewerMessagePage(
        icon: Icons.menu_book_outlined,
        title: l10n.viewerContentMissingTitle,
        message: l10n.viewerContentMissingBody,
      );
    }

    final settings = ref.watch(novelReaderSettingsProvider).value ?? const NovelReaderSettings();
    final theme = settings.theme;
    final background = Color(theme.background);
    final foreground = Color(theme.foreground);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(24, topInset + 72, 24, 140),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          chapter.title,
                          style: TextStyle(
                            fontSize: settings.fontSize + 6,
                            fontWeight: FontWeight.bold,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (chapter.paragraphs.isEmpty)
                          Text(
                            l10n.viewerNovelEmpty,
                            style: TextStyle(color: foreground.withValues(alpha: 0.6)),
                          ),
                        for (final paragraph in chapter.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              paragraph,
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                height: settings.lineHeight,
                                color: foreground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_chromeVisible) _buildTopBar(l10n, content, chapter, background, foreground),
          if (_chromeVisible) _buildBottomBar(l10n, content, background, foreground),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    AppLocalizations l10n,
    NovelViewerContent content,
    NovelChapter chapter,
    Color background,
    Color foreground,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        color: background.withValues(alpha: 0.94),
        padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 8, 8),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _handleBack,
              tooltip: l10n.viewerBack,
              color: foreground,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 16),
                  ),
                  Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _openCatalog,
              tooltip: l10n.viewerCatalog,
              color: foreground,
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    AppLocalizations l10n,
    NovelViewerContent content,
    Color background,
    Color foreground,
  ) {
    final hasPrevious = _chapterIndex > 0;
    final hasNext = _chapterIndex < content.chapters.length - 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: background.withValues(alpha: 0.94),
        padding: EdgeInsets.fromLTRB(8, 4, 8, MediaQuery.paddingOf(context).bottom + 4),
        child: Row(
          children: <Widget>[
            TextButton(
              onPressed: hasPrevious ? () => _switchChapter(_chapterIndex - 1) : null,
              child: Text(l10n.viewerPreviousChapter),
            ),
            TextButton(
              onPressed: hasNext ? () => _switchChapter(_chapterIndex + 1) : null,
              child: Text(l10n.viewerNextChapter),
            ),
            const Spacer(),
            IconButton(
              onPressed: _openSettings,
              tooltip: l10n.novelReaderSettings,
              color: foreground,
              icon: const Icon(Icons.text_fields),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _handleScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => unawaited(_saveProgress()));
  }

  String _progressKey(NovelViewerContent content, NovelChapter chapter) =>
      '$_progressPrefix:${content.title}:${chapter.id}';

  Future<void> _saveProgress() async {
    final content = _content;
    final chapter = _chapter;
    if (content == null || chapter == null || !_scrollController.hasClients) {
      return;
    }
    final offset = _scrollController.offset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_progressKey(content, chapter), offset);
  }

  Future<void> _restoreProgress() async {
    final content = _content;
    final chapter = _chapter;
    if (content == null || chapter == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final offset = prefs.getDouble(_progressKey(content, chapter)) ?? 0;
    if (!mounted || offset <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset > max ? max : offset);
    });
  }

  Future<void> _switchChapter(int index) async {
    final content = _content;
    if (content == null || index < 0 || index >= content.chapters.length) {
      return;
    }
    await _saveProgress();
    if (!mounted) {
      return;
    }
    setState(() {
      _chapterIndex = index;
      _chromeVisible = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(_restoreProgress());
  }

  Future<void> _openCatalog() async {
    final content = _content;
    if (content == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.viewerCatalog, style: Theme.of(context).textTheme.titleMedium),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: content.chapters.length,
                itemBuilder: (context, index) => ListTile(
                  selected: index == _chapterIndex,
                  title: Text(content.chapters[index].title),
                  onTap: () => Navigator.of(context).pop(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (selected != null && selected != _chapterIndex) {
      await _switchChapter(selected);
    }
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const NovelSettingsSheet(),
    );
    if (!mounted) {
      return;
    }
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }
}
