import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../manga_page_view.dart';
import 'utils.dart';
import 'widgets/interactive_panel.dart';
import 'widgets/page_strip.dart';

class MangaPageContinuousView extends StatefulWidget {
  const MangaPageContinuousView({
    super.key,
    required this.controller,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
    required this.viewportSize,
    this.onPageChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Size viewportSize;
  final Function(int index)? onPageChange;
  final Function(MangaPageViewScrollProgress progress)? onProgressChange;

  @override
  State<MangaPageContinuousView> createState() =>
      _MangaPageContinuousViewState();
}

class _MangaPageContinuousViewState extends State<MangaPageContinuousView> {
  final _interactionPanelKey = GlobalKey<MangaPageInteractivePanelState>();
  final _stripContainerKey = GlobalKey<MangaPageStripState>();

  double _scrollBoundMin = 0;
  double _scrollBoundMax = 0;
  Offset _currentOffset = Offset.zero;
  int _currentPage = 0;
  double _currentZoomLevel = 1.0;
  bool _isChangingPage = false;

  MangaPageInteractivePanelState get _panelState =>
      _interactionPanelKey.currentState!;
  MangaPageStripState get _stripState => _stripContainerKey.currentState!;

  late final _pageUpdateThrottler = Throttler(Duration(milliseconds: 100));

  @override
  void initState() {
    super.initState();
    widget.controller.pageChangeRequest.addListener(_onPageChangeRequest);
    widget.controller.fractionChangeRequest.addListener(
      _onFractionChangeRequest,
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.fractionChangeRequest.removeListener(
      _onFractionChangeRequest,
    );
    widget.controller.pageChangeRequest.removeListener(_onPageChangeRequest);
  }

  @override
  void didUpdateWidget(covariant MangaPageContinuousView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.options.direction != oldWidget.options.direction) {
      final targetPage = _currentPage;
      _isChangingPage = true;
      Future.delayed(Duration(milliseconds: 50), () {
        _moveToPage(targetPage);
      });
    }
  }

  void _onPageChangeRequest() {
    final pageIndex = widget.controller.pageChangeRequest.value;

    if (pageIndex != null) {
      _animateToPage(pageIndex);
      widget.controller.fractionChangeRequest.value = null;
    }
  }

  void _onPageChangeAnimationEnd() {
    _isChangingPage = false;
  }

  void _onFractionChangeRequest() {
    final fraction = widget.controller.fractionChangeRequest.value;

    if (fraction != null) {
      final targetOffset = _fractionToOffset(fraction);
      _panelState.jumpToOffset(targetOffset);
      widget.controller.fractionChangeRequest.value = null;
    }
  }

  Offset _getPageJumpOffset(Rect pageBounds) {
    final viewport = widget.viewportSize;
    final padding = (viewport / 2) * (1 - 1 / _currentZoomLevel);

    final bounds = Rect.fromLTRB(
      pageBounds.left - padding.width,
      pageBounds.top - padding.height,
      pageBounds.right + padding.width,
      pageBounds.bottom + padding.height,
    );

    final gravity = widget.options.pageJumpGravity;
    final viewportCenter = viewport.center(Offset.zero);

    return switch (widget.options.direction) {
      PageViewDirection.down => gravity.select(
        start: bounds.topCenter,
        center: bounds.center.translate(0, -viewportCenter.dy),
        end: bounds.bottomCenter.translate(0, -viewport.height),
      ),
      PageViewDirection.up => gravity.select(
        start: bounds.bottomCenter,
        center: bounds.center.translate(0, viewportCenter.dy),
        end: bounds.topCenter.translate(0, viewport.height),
      ),
      PageViewDirection.right => gravity.select(
        start: bounds.centerLeft,
        center: bounds.center.translate(-viewportCenter.dx, 0),
        end: bounds.centerRight.translate(-viewport.width, 0),
      ),
      PageViewDirection.left => gravity.select(
        start: bounds.centerRight,
        center: bounds.center.translate(viewportCenter.dx, 0),
        end: bounds.centerLeft.translate(viewport.width, 0),
      ),
    };
  }

  void _moveToPage(int pageIndex) {
    final pageRect = _stripState.pageBounds[pageIndex];
    _panelState.jumpToOffset(_getPageJumpOffset(pageRect));
    widget.onPageChange?.call(pageIndex);
    _currentPage = pageIndex;
    _isChangingPage = false;
  }

  void _animateToPage(int pageIndex) {
    final pageRect = _stripState.pageBounds[pageIndex];
    _isChangingPage = true;

    widget.onPageChange?.call(pageIndex);
    _currentPage = pageIndex;

    _panelState.animateToOffset(
      _getPageJumpOffset(pageRect),
      _onPageChangeAnimationEnd,
    );
  }

  void _handleScroll(ScrollInfo info) {
    final scrollableRegion = _panelState.scrollableRegion;
    switch (widget.options.direction) {
      case PageViewDirection.up:
        _scrollBoundMin = scrollableRegion.bottom;
        _scrollBoundMax = scrollableRegion.top;
      case PageViewDirection.down:
        _scrollBoundMin = scrollableRegion.top;
        _scrollBoundMax = scrollableRegion.bottom;
      case PageViewDirection.left:
        _scrollBoundMin = scrollableRegion.right;
        _scrollBoundMax = scrollableRegion.left;
      case PageViewDirection.right:
        _scrollBoundMin = scrollableRegion.left;
        _scrollBoundMax = scrollableRegion.right;
    }

    _currentOffset = info.offset;
    _currentZoomLevel = info.zoomLevel;

    final viewRegion = _computeVisibleWindow(
      info.offset,
      info.zoomLevel,
      widget.viewportSize,
    );
    if (!viewRegion.isEmpty) {
      _pageUpdateThrottler.call(() {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _stripState.glance(viewRegion);
          _updatePageIndex(viewRegion);
        });
      });
    }

    final fraction = _offsetToFraction(info.offset);

    widget.onProgressChange?.call(
      MangaPageViewScrollProgress(
        currentPage: 1,
        totalPages: 1,
        fraction: fraction,
      ),
    );
  }

  void _onPageSizeChanged(int pageIndex) {
    // print('Page index change: $pageIndex');
    // if (pageIndex <= _currentPage) {
    //   print('Reorient: $_currentPage');
    //   _moveToPage(_currentPage);
    // }
  }

  void _updatePageIndex(Rect viewRegion) {
    final bounds = _stripState.pageBounds;
    final gravity = widget.options.pageSenseGravity;

    final screenEdge = switch (widget.options.direction) {
      PageViewDirection.down => gravity.select(
        start: viewRegion.top,
        center: viewRegion.center.dy,
        end: viewRegion.bottom,
      ),
      PageViewDirection.up => gravity.select(
        start: -viewRegion.bottom,
        center: -viewRegion.center.dy,
        end: -viewRegion.top,
      ),
      PageViewDirection.left => gravity.select(
        start: -viewRegion.right,
        center: -viewRegion.center.dx,
        end: -viewRegion.left,
      ),
      PageViewDirection.right => gravity.select(
        start: viewRegion.left,
        center: viewRegion.center.dx,
        end: viewRegion.right,
      ),
    };
    final pageEdge = switch (widget.options.direction) {
      PageViewDirection.down => (Rect b) => b.top,
      PageViewDirection.up => (Rect b) => -b.bottom,
      PageViewDirection.left => (Rect b) => -b.right,
      PageViewDirection.right => (Rect b) => b.left,
    };

    int checkIndex = -1;
    for (int i = 0; i < widget.itemCount; i++) {
      if (pageEdge(bounds[i]) >= screenEdge) {
        break;
      }
      checkIndex += 1;
    }

    final pageIndex = checkIndex.clamp(0, widget.itemCount - 1);

    if (!_isChangingPage && _currentPage != pageIndex) {
      widget.onPageChange?.call(pageIndex);
      _currentPage = pageIndex;
    }
  }

  double _offsetToFraction(Offset offset) {
    final double current;
    final double min;
    final double max;

    switch (widget.options.direction) {
      case PageViewDirection.up:
        current = offset.dy;
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.down:
        current = offset.dy;
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
      case PageViewDirection.left:
        current = offset.dx;
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.right:
        current = offset.dx;
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
    }
    if (max - min == 0) {
      return 0;
    }
    return ((current - min) / (max - min)).clamp(0, 1);
  }

  Offset _fractionToOffset(double fraction) {
    final double target;
    final double min;
    final double max;

    switch (widget.options.direction) {
      case PageViewDirection.up:
      case PageViewDirection.left:
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.down:
      case PageViewDirection.right:
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
    }
    target = min + (max - min) * fraction;

    return switch (widget.options.direction) {
      PageViewDirection.up ||
      PageViewDirection.down => Offset(_currentOffset.dx, target),
      PageViewDirection.left ||
      PageViewDirection.right => Offset(target, _currentOffset.dy),
    };
  }

  Rect _computeVisibleWindow(
    Offset offset,
    double zoomLevel,
    Size viewportSize,
  ) {
    final viewportCenter = viewportSize.center(Offset.zero);
    final worldCenter = offset + viewportCenter;

    final halfSizeInWorld = Offset(
      viewportSize.width / zoomLevel / 2,
      viewportSize.height / zoomLevel / 2,
    );

    final topLeft = worldCenter - halfSizeInWorld;
    final size = viewportSize / zoomLevel;

    final visibleRect = topLeft & size;

    // Adjust window on left and up direction mode
    return switch (widget.options.direction) {
      PageViewDirection.up => visibleRect.translate(0, viewportSize.height),
      PageViewDirection.down => visibleRect,
      PageViewDirection.left => visibleRect.translate(-viewportSize.width, 0),
      PageViewDirection.right => visibleRect,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MangaPageInteractivePanel(
      key: _interactionPanelKey,
      initialZoomLevel: widget.options.initialZoomLevel,
      minZoomLevel: widget.options.minZoomLevel,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels,
      zoomOnFocalPoint: widget.options.zoomOnFocalPoint,
      zoomOvershoot: widget.options.zoomOvershoot,
      verticalOverscroll:
          widget.options.direction.isVertical &&
              widget.options.mainAxisOverscroll ||
          widget.options.direction.isHorizontal &&
              widget.options.crossAxisOverscroll,
      horizontalOverscroll:
          widget.options.direction.isHorizontal &&
              widget.options.mainAxisOverscroll ||
          widget.options.direction.isVertical &&
              widget.options.crossAxisOverscroll,
      alignment: switch (widget.options.direction) {
        PageViewDirection.down => PanelAlignment.top,
        PageViewDirection.right => PanelAlignment.left,
        PageViewDirection.up => PanelAlignment.bottom,
        PageViewDirection.left => PanelAlignment.right,
      },
      viewportSize: widget.viewportSize,
      child: MangaPageStrip(
        key: _stripContainerKey,
        viewportSize: widget.viewportSize,
        direction: widget.options.direction,
        spacing: widget.options.spacing,
        initialPageSize: widget.options.initialPageSize,
        maxPageSize: widget.options.maxPageSize,
        precacheOverhead: widget.options.precacheOverhead,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
        onPageSizeChanged: _onPageSizeChanged,
      ),
      onScroll: _handleScroll,
    );
  }
}
