import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'widgets/continuous_view.dart';
import 'widgets/paged_view.dart';
import 'widgets/viewport_size.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    this.onPageChange,
    this.onZoomChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(double zoomLevel)? onZoomChange;
  final Function(double progress)? onProgressChange;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView> {
  late int _currentPage = 0;

  void _onPageChange(int pageIndex) {
    _currentPage = pageIndex;
    widget.onPageChange?.call(pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ViewportSize(
      child: switch (widget.options.mode) {
        MangaPageViewMode.continuous => MangaPageContinuousView(
          initialPageIndex: _currentPage,
          controller: widget.controller,
          options: widget.options,
          pageCount: widget.pageCount,
          pageBuilder: widget.pageBuilder,
          onPageChange: _onPageChange,
          onProgressChange: widget.onProgressChange,
          onZoomChange: widget.onZoomChange,
        ),
        MangaPageViewMode.paged => MangaPagePagedView(
          controller: widget.controller,
          initialPageIndex: _currentPage,
          options: widget.options,
          pageCount: widget.pageCount,
          pageBuilder: widget.pageBuilder,
          onPageChange: _onPageChange,
          onProgressChange: widget.onProgressChange,
          onZoomChange: widget.onZoomChange,
        ),
      },
    );
  }
}
