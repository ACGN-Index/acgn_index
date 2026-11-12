import 'dart:async';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_message_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 漫画查看器：横向翻页 + 双指缩放，点击画面切换沉浸式 UI。
class ComicViewerPage extends StatefulWidget {
  const ComicViewerPage({this.content, super.key});

  final ComicViewerContent? content;

  @override
  State<ComicViewerPage> createState() => _ComicViewerPageState();
}

class _ComicViewerPageState extends State<ComicViewerPage> {
  static final Logger _logger = AppLogger.of('viewer.comic');

  int _pageIndex = 0;
  PageController? _pageController;
  bool _chromeVisible = true;
  bool _loadingChapter = false;
  List<ViewerChapterRef> _chapterRefs = const <ViewerChapterRef>[];
  ComicChapter? _chapter;
  String? _chapterKey;

  ComicViewerContent? get _content => widget.content;

  int get _currentRefIndex {
    final index = _chapterRefs.indexWhere((ref) => ref.key == _chapterKey);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    if (content == null || content.chapters.isEmpty) {
      return;
    }
    _chapterRefs = _buildRefs(content);
    _chapter = content.chapters[content.safeInitialChapterIndex];
    _chapterKey =
        content.initialChapterKey ??
        (_chapterRefs.isEmpty ? null : _chapterRefs[content.safeInitialChapterIndex].key);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  List<ViewerChapterRef> _buildRefs(ComicViewerContent content) {
    final source = content.chapterSource;
    if (source != null && source.chapters.isNotEmpty) {
      return source.chapters;
    }
    return content.chapters
        .map((chapter) => ViewerChapterRef(key: chapter.id, title: chapter.title))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    final chapter = _chapter;
    if (content == null || chapter == null) {
      return ViewerMessagePage(
        icon: Icons.photo_library_outlined,
        title: l10n.viewerContentMissingTitle,
        message: l10n.viewerContentMissingBody,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildGallery(l10n, chapter)),
          if (_loadingChapter)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_chromeVisible) _buildTopBar(l10n, content, chapter),
          if (_chromeVisible) _buildBottomBar(l10n),
        ],
      ),
    );
  }

  Widget _buildGallery(AppLocalizations l10n, ComicChapter chapter) {
    if (chapter.pages.isEmpty) {
      return Center(
        child: Text(l10n.viewerComicEmpty, style: const TextStyle(color: Colors.white70)),
      );
    }
    return PhotoViewGallery.builder(
      key: ValueKey<String>(_chapterKey ?? chapter.id),
      pageController: _pageController,
      itemCount: chapter.pages.length,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
      onPageChanged: (index) => _handlePageChanged(chapter, index),
      builder: (context, index) {
        final page = chapter.pages[index];
        return PhotoViewGalleryPageOptions(
          imageProvider: _imageProvider(page),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained * 4,
          onTapUp: (context, details, controllerValue) => _toggleChrome(),
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              l10n.viewerImageLoadFailed,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    AppLocalizations l10n,
    ComicViewerContent content,
    ComicChapter chapter,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 4, 16, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _handleBack,
              tooltip: l10n.viewerBack,
              color: Colors.white,
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
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (chapter.pages.isNotEmpty)
              Text(
                l10n.viewerPageOf(_pageIndex + 1, chapter.pages.length),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    final hasPrevious = _currentRefIndex > 0;
    final hasNext = _currentRefIndex < _chapterRefs.length - 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 16, 12, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            TextButton.icon(
              onPressed: hasPrevious ? () => _switchChapter(-1) : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(l10n.viewerPreviousChapter),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            TextButton.icon(
              onPressed: _openCatalog,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(l10n.viewerCatalog),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            TextButton.icon(
              onPressed: hasNext ? () => _switchChapter(1) : null,
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.viewerNextChapter),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider<Object> _imageProvider(ViewerMedia media) => CachedNetworkImageProvider(
    media.uri.toString(),
    headers: media.hasHeaders ? media.headers : null,
  );

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _handlePageChanged(ComicChapter chapter, int index) {
    setState(() => _pageIndex = index);
    final next = index + 1;
    if (next < chapter.pages.length) {
      unawaited(precacheImage(_imageProvider(chapter.pages[next]), context));
    }
  }

  Future<void> _openCatalog() async {
    if (_chapterRefs.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<ViewerChapterRef>(
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
                itemCount: _chapterRefs.length,
                itemBuilder: (context, index) => ListTile(
                  selected: _chapterRefs[index].key == _chapterKey,
                  title: Text(_chapterRefs[index].title),
                  onTap: () => Navigator.of(context).pop(_chapterRefs[index]),
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
    if (selected != null) {
      await _selectChapter(selected);
    }
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  void _switchChapter(int delta) {
    final index = _currentRefIndex + delta;
    if (index < 0 || index >= _chapterRefs.length) {
      return;
    }
    unawaited(_selectChapter(_chapterRefs[index]));
  }

  Future<void> _selectChapter(ViewerChapterRef ref) async {
    if (ref.key == _chapterKey) {
      return;
    }
    final content = _content;
    if (content == null) {
      return;
    }
    final source = content.chapterSource;
    if (source == null) {
      final index = _chapterRefs.indexWhere((candidate) => candidate.key == ref.key);
      if (index < 0 || index >= content.chapters.length) {
        return;
      }
      _applyChapter(content.chapters[index], ref.key);
      return;
    }
    setState(() => _loadingChapter = true);
    try {
      final launch = await source.load(ref);
      if (!mounted) {
        return;
      }
      if (launch is! ComicViewerLaunch || launch.content.chapters.isEmpty) {
        throw const UnsupportedCapabilityException('该章节没有可阅读的图片');
      }
      _applyChapter(launch.content.chapters.first, ref.key);
    } on Object catch (error, stackTrace) {
      _logger.warning('切换章节失败：${ref.key}', error, stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).viewerChapterLoadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingChapter = false);
      }
    }
  }

  void _applyChapter(ComicChapter chapter, String key) {
    final previous = _pageController;
    setState(() {
      _chapter = chapter;
      _chapterKey = key;
      _pageIndex = 0;
      _pageController = PageController();
      _chromeVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }
}
