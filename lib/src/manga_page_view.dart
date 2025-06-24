import 'package:flutter/widgets.dart';
import '../manga_page_view.dart';
import 'widgets/page_end_gesture_wrapper.dart';
import 'widgets/continuous_view.dart';
import 'widgets/paged_view.dart';
import 'widgets/viewport_size.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    required this.mode,
    this.options = const MangaPageViewOptions(),
    this.controller,
    required this.pageCount,
    required this.pageBuilder,
    this.onPageChange,
    this.onZoomChange,
    this.onProgressChange,
    this.pageEndGestureIndicatorBuilder,
    this.onStartEdgeDrag,
    this.onEndEdgeDrag,
  }) : assert(
         (onStartEdgeDrag != null || onEndEdgeDrag != null)
             ? pageEndGestureIndicatorBuilder != null
             : true,
         "When using edge drag gestures, pageEndGestureIndicatorBuilder must not be null",
       );

  final MangaPageViewMode mode;
  final MangaPageViewController? controller;
  final MangaPageViewOptions options;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(double zoomLevel)? onZoomChange;
  final Function(double progress)? onProgressChange;
  final Widget Function(
    BuildContext context,
    MangaPageViewEdgeGestureInfo info,
  )?
  pageEndGestureIndicatorBuilder;
  final VoidCallback? onStartEdgeDrag;
  final VoidCallback? onEndEdgeDrag;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView> {
  late int _currentPage = 0;
  late final _defaultController = MangaPageViewController();
  late MangaPageViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _defaultController;
  }

  @override
  void didUpdateWidget(covariant MangaPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller = widget.controller ?? _defaultController;
  }

  @override
  void dispose() {
    super.dispose();
    _defaultController.dispose();
  }

  bool get isEdgeGesturesEnabled =>
      widget.onStartEdgeDrag != null || widget.onEndEdgeDrag != null;

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
    Widget child = switch (widget.mode) {
      MangaPageViewMode.continuous => MangaPageContinuousView(
        initialPageIndex: _currentPage,
        controller: _controller,
        options: widget.options,
        pageCount: widget.pageCount,
        pageBuilder: widget.pageBuilder,
        onPageChange: _onPageChange,
        onProgressChange: _onProgressChange,
        onZoomChange: _onZoomChange,
      ),
      MangaPageViewMode.paged => MangaPagePagedView(
        controller: _controller,
        initialPageIndex: _currentPage,
        options: widget.options,
        pageCount: widget.pageCount,
        pageBuilder: widget.pageBuilder,
        onPageChange: _onPageChange,
        onProgressChange: _onProgressChange,
        onZoomChange: _onZoomChange,
      ),
    };

    if (isEdgeGesturesEnabled) {
      child = PageEndGestureWrapper(
        direction: widget.options.direction,
        indicatorSize: widget.options.edgeIndicatorContainerSize,
        indicatorBuilder: widget.pageEndGestureIndicatorBuilder!,
        onStartEdgeDrag: widget.onStartEdgeDrag,
        onEndEdgeDrag: widget.onEndEdgeDrag,
        child: child,
      );
    }

    return ViewportSize(child: child);
  }
}
