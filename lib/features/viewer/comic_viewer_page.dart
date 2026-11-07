import 'dart:async';

import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/widgets/viewer_message_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  int _chapterIndex = 0;
  int _pageIndex = 0;
  PageController? _pageController;
  bool _chromeVisible = true;

  ComicViewerContent? get _content => widget.content;

  ComicChapter? get _chapter {
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
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
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
          if (_chromeVisible) _buildTopBar(l10n, content, chapter),
          if (_chromeVisible) _buildBottomBar(l10n, content),
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
      key: ValueKey<int>(_chapterIndex),
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

  Widget _buildBottomBar(AppLocalizations l10n, ComicViewerContent content) {
    final hasPrevious = _chapterIndex > 0;
    final hasNext = _chapterIndex < content.chapters.length - 1;
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
              onPressed: hasPrevious ? () => _switchChapter(_chapterIndex - 1) : null,
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
              onPressed: hasNext ? () => _switchChapter(_chapterIndex + 1) : null,
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
      _switchChapter(selected);
    }
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  void _switchChapter(int index) {
    final content = _content;
    if (content == null || index < 0 || index >= content.chapters.length) {
      return;
    }
    final previous = _pageController;
    setState(() {
      _chapterIndex = index;
      _pageIndex = 0;
      _pageController = PageController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    }
  }
}
