import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/domain/repositories/work_repository.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';

/// 把整部作品的目录暴露给查看器，并在切换章节时回到仓储实时抓取。
class RuleWorkChapterSource implements ViewerChapterSource {
  RuleWorkChapterSource({required this.repository, required WorkView work})
    : _work = work,
      _entries = work.toc.entries,
      chapters = List<ViewerChapterRef>.unmodifiable(
        work.toc.entries.map(
          (entry) => ViewerChapterRef(
            key: entry.key,
            title: entry.title,
            groupTitle: entry.groupTitle ?? entry.group,
            order: entry.order,
          ),
        ),
      );

  final WorkRepository repository;
  final WorkView _work;
  final List<TocEntry> _entries;

  @override
  final List<ViewerChapterRef> chapters;

  @override
  Future<ViewerLaunch> load(ViewerChapterRef chapter) {
    final entry = _entries.where((candidate) => candidate.key == chapter.key).firstOrNull;
    if (entry == null) {
      throw StorageException('目录中不存在该章节：${chapter.key}');
    }
    return repository.loadChapter(_work, entry);
  }
}
