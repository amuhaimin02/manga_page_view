import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:manga_page_view/src/utils.dart';
import 'package:manga_page_view/src/widgets/page_end_gesture_wrapper.dart';
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
    Future.microtask(() => widget.onPageChange?.call(pageIndex));
  }

  void _onProgressChange(double progress) {
    Future.microtask(() => widget.onProgressChange?.call(progress));
  }

  void _onZoomChange(double zoomLevel) {
    Future.microtask(() => widget.onZoomChange?.call(zoomLevel));
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (event) {
        print(event);
        return false;
      },
      child: ViewportSize(
        child: PageEndGestureWrapper(
          detectionAxis: widget.options.direction.axis,
          child: switch (widget.options.mode) {
            MangaPageViewMode.continuous => MangaPageContinuousView(
              initialPageIndex: _currentPage,
              controller: widget.controller,
              options: widget.options,
              pageCount: widget.pageCount,
              pageBuilder: widget.pageBuilder,
              onPageChange: _onPageChange,
              onProgressChange: _onProgressChange,
              onZoomChange: _onZoomChange,
            ),
            MangaPageViewMode.paged => MangaPagePagedView(
              controller: widget.controller,
              initialPageIndex: _currentPage,
              options: widget.options,
              pageCount: widget.pageCount,
              pageBuilder: widget.pageBuilder,
              onPageChange: _onPageChange,
              onProgressChange: _onProgressChange,
              onZoomChange: _onZoomChange,
            ),
          },
        ),
      ),
    );
  }
}
