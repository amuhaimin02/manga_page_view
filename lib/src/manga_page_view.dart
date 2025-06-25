import 'package:flutter/widgets.dart';

import '../manga_page_view.dart';
import 'widgets/continuous_view.dart';
import 'widgets/page_end_gesture_wrapper.dart';
import 'widgets/paged_view.dart';
import 'widgets/viewport_size.dart';

/// A widget designed for displaying manga, comics, or any
/// sequence of paged content.
///
/// [MangaPageView] offers a rich set of features to enhance the reading
/// experience, including:
///
/// *   Multiple viewing modes: Supports both continuous scrolling
///     (`MangaPageViewMode.continuous`) and traditional paginated display
///     (`MangaPageViewMode.paged`) with four-way reading directions.
/// *   Customization: Allows fine-grained control over appearance and
///     behavior through `MangaPageViewOptions`, including initial page,
///     reading direction (e.g., left-to-right, right-to-left), and zoom levels.
/// *   Navigation: Facilitates navigation with edge gestures for moving
///     between chapters or sections, providing a seamless reading flow.
/// *   State management: Can be managed with an optional `MangaPageViewController`
///     for programmatic control over the view.
class MangaPageView extends StatefulWidget {
  /// Creates the [MangaPageView] widget that shows its children in a comic or manga page viewer
  const MangaPageView({
    super.key,
    required this.mode,
    required this.direction,
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
       ),
       assert(pageCount > 0, "pageCount must be greater than 0");

  /// The viewing mode for the manga pages.
  ///
  /// See [MangaPageViewMode] for available options.
  final MangaPageViewMode mode;

  /// The direction in which pages are laid out and scrolled.
  ///
  /// Direction indicates which way the user should scroll in order to move forward to view the next page.
  ///
  /// - For top-down traditional view, use [MangaPageViewDirection.down]
  /// - For left-to-right reading, use [MangaPageViewDirection.right]
  /// - For right-to-left reading, use [MangaPageViewDirection.left]
  /// - For bottom-up reading, use [MangaPageViewDirection.up]
  final MangaPageViewDirection direction;

  /// An optional controller for managing the state of the [MangaPageView].
  final MangaPageViewController? controller;

  /// Options for customizing the appearance and behavior of the [MangaPageView].
  ///
  /// See [MangaPageViewOptions] for available options.
  final MangaPageViewOptions options;

  /// The total number of pages available.
  final int pageCount;

  /// A builder function that creates the widget for each page.
  final IndexedWidgetBuilder pageBuilder;

  /// A callback function that is invoked when the current page changes.
  final Function(int index)? onPageChange;

  /// A callback function that is invoked when the zoom level changes.
  final Function(double zoomLevel)? onZoomChange;

  /// A callback function that is invoked when the scroll progress changes.
  /// Value will be between 0.0 and 1.0 inclusive, for start and end, respectively
  final Function(double progress)? onProgressChange;

  /// A builder function for the indicator displayed during edge gestures.
  ///
  /// This is only used if [onStartEdgeDrag] or [onEndEdgeDrag] is provided.
  /// Therefore, if either one of the callbacks is provided, this builder should not be null.
  final Widget Function(
    BuildContext context,
    MangaPageViewEdgeGestureInfo info,
  )?
  pageEndGestureIndicatorBuilder;

  /// A callback function that is invoked when an edge gesture starts from the
  /// beginning of the page.
  final VoidCallback? onStartEdgeDrag;

  /// A callback function that is invoked when an edge gesture starts from the
  /// end of the page.
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

  /// Indicates whether edge gestures are enabled.
  bool get _isEdgeGesturesEnabled =>
      widget.onStartEdgeDrag != null || widget.onEndEdgeDrag != null;

  /// Handles page changes and invokes the [onPageChange] callback.
  void _onPageChange(int pageIndex) {
    _currentPage = pageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPageChange?.call(pageIndex);
      _controller.notifyPageChange(pageIndex);
    });
  }

  /// Handles progress changes and invokes the [onProgressChange] callback.
  void _onProgressChange(double progress) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onProgressChange?.call(progress);
      _controller.notifyProgressChange(progress);
    });
  }

  /// Handles zoom level changes and invokes the [onZoomChange] callback.
  void _onZoomChange(double zoomLevel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onZoomChange?.call(zoomLevel);
      _controller.notifyZoomChange(zoomLevel);
    });
  }

  /// Builds the widget tree for the [MangaPageView].
  /// It determines the appropriate view (continuous or paged) based on the [mode].
  @override
  Widget build(BuildContext context) {
    Widget child = switch (widget.mode) {
      MangaPageViewMode.continuous => MangaPageContinuousView(
        initialPageIndex: _currentPage,
        controller: _controller,
        direction: widget.direction,
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
        direction: widget.direction,
        options: widget.options,
        pageCount: widget.pageCount,
        pageBuilder: widget.pageBuilder,
        onPageChange: _onPageChange,
        onProgressChange: _onProgressChange,
        onZoomChange: _onZoomChange,
      ),
    };

    if (_isEdgeGesturesEnabled) {
      child = PageEndGestureWrapper(
        direction: widget.direction,
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
