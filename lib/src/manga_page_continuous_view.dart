import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:manga_page_view/src/widgets/viewport.dart';

import '../manga_page_view.dart';
import 'widgets/interactive_panel.dart';

class MangaPageContinuousView extends StatefulWidget {
  const MangaPageContinuousView({
    super.key,
    required this.controller,
    required this.options,
    required this.initialPageIndex,
    required this.pageCount,
    required this.pageBuilder,
    this.onPageChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int initialPageIndex;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(MangaPageViewScrollProgress progress)? onProgressChange;

  @override
  State<MangaPageContinuousView> createState() =>
      _MangaPageContinuousViewState();
}

class _MangaPageContinuousViewState extends State<MangaPageContinuousView> {
  final _interactionPanelKey = GlobalKey<InteractivePanelState>();
  final _stripContainerKey = GlobalKey<_PageStripState>();

  double _scrollBoundMin = 0;
  double _scrollBoundMax = 0;
  Offset _currentOffset = Offset.zero;
  int _currentPage = 0;
  late double _currentZoomLevel = widget.options.initialZoomLevel;
  bool _isChangingPage = false;

  InteractivePanelState get _panelState => _interactionPanelKey.currentState!;
  _PageStripState get _stripState => _stripContainerKey.currentState!;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

  @override
  void initState() {
    super.initState();
    widget.controller.pageChangeRequest.addListener(_onPageChangeRequest);
    widget.controller.fractionChangeRequest.addListener(
      _onFractionChangeRequest,
    );
    _loadOnPage(widget.initialPageIndex);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.fractionChangeRequest.removeListener(
      _onFractionChangeRequest,
    );
    widget.controller.pageChangeRequest.removeListener(_onPageChangeRequest);
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
    _updatePageDisplay();
  }

  void _onFractionChangeRequest() {
    final fraction = widget.controller.fractionChangeRequest.value;

    if (fraction != null) {
      _isChangingPage = false;
      final targetOffset = _fractionToOffset(fraction);
      _panelState.jumpToOffset(targetOffset);
      widget.controller.fractionChangeRequest.value = null;
    }
  }

  Offset _getPageJumpOffset(Rect pageBounds) {
    final viewport = _viewportSize;
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

  void _loadOnPage(int pageIndex) {
    _isChangingPage = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final pageRect = _stripState.pageBounds[pageIndex];
      _panelState.animateToOffset(
        _getPageJumpOffset(pageRect),
        _onPageChangeAnimationEnd,
      );
    });
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

  void _handleScroll(Offset offset, double zoomLevel) {
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

    _currentOffset = offset;
    _currentZoomLevel = zoomLevel;

    if (!_isChangingPage) {
      _updatePageDisplay();
    }
  }

  void _updatePageDisplay() {
    final viewRegion = _computeVisibleWindow(
      _currentOffset,
      _currentZoomLevel,
      _viewportSize,
    );
    if (!viewRegion.isEmpty) {
      _stripState.glance(viewRegion);
      _updatePageIndex(viewRegion);
    }
    final fraction = _offsetToFraction(_currentOffset);

    widget.onProgressChange?.call(
      MangaPageViewScrollProgress(
        currentPage: 1,
        totalPages: 1,
        fraction: fraction,
      ),
    );
  }

  void _onPageSizeChanged(int pageIndex) {}

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
    final differenceTolerance = 20;

    for (int i = 0; i < widget.pageCount; i++) {
      if (pageEdge(bounds[i]) - screenEdge > differenceTolerance) {
        break;
      }
      checkIndex += 1;
    }

    final pageIndex = checkIndex.clamp(0, widget.pageCount - 1);

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
      PageViewDirection.up => visibleRect.translate(0, -viewportSize.height),
      PageViewDirection.down => visibleRect,
      PageViewDirection.left => visibleRect.translate(-viewportSize.width, 0),
      PageViewDirection.right => visibleRect,
    };
  }

  @override
  Widget build(BuildContext context) {
    return InteractivePanel(
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
        PageViewDirection.down => InteractivePanelAlignment.top,
        PageViewDirection.right => InteractivePanelAlignment.left,
        PageViewDirection.up => InteractivePanelAlignment.bottom,
        PageViewDirection.left => InteractivePanelAlignment.right,
      },
      panCheckAxis: null,
      child: _PageStrip(
        key: _stripContainerKey,
        direction: widget.options.direction,
        spacing: widget.options.spacing,
        initialPageSize: widget.options.initialPageSize,
        maxPageSize: widget.options.maxPageSize,
        precacheAhead: widget.options.precacheAhead,
        precacheBehind: widget.options.precacheBehind,
        pageCount: widget.pageCount,
        pageBuilder: widget.pageBuilder,
        onPageSizeChanged: _onPageSizeChanged,
      ),
      onScroll: _handleScroll,
    );
  }
}

class _PageStrip extends StatefulWidget {
  const _PageStrip({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    required this.direction,
    required this.spacing,
    required this.initialPageSize,
    required this.maxPageSize,
    required this.precacheAhead,
    required this.precacheBehind,
    required this.onPageSizeChanged,
  });

  final PageViewDirection direction;
  final double spacing;
  final Size initialPageSize;
  final Size maxPageSize;
  final int precacheAhead;
  final int precacheBehind;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int pageIndex) onPageSizeChanged;

  @override
  State<_PageStrip> createState() => _PageStripState();
}

class _PageStripState extends State<_PageStrip> {
  late Map<int, Widget> _loadedWidgets = {};
  late List<Rect> _pageBounds;

  List<Rect> get pageBounds => _pageBounds;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

  @override
  void initState() {
    super.initState();
    _pageBounds = List.filled(
      widget.pageCount,
      Offset.zero & widget.initialPageSize,
    );
    _updatePageBounds();
  }

  @override
  void didUpdateWidget(covariant _PageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction ||
        widget.spacing != oldWidget.spacing) {
      _updatePageBounds();
    }
  }

  void _onPageSizeChanged(BuildContext context, int index) {
    final pageSize = (context.findRenderObject() as RenderBox).size;
    _pageBounds[index] = Offset.zero & pageSize;
    _updatePageBounds();
    widget.onPageSizeChanged(index);
  }

  void _updatePageBounds() {
    final pageCount = widget.pageCount;
    Offset nextPoint = Offset.zero;
    for (int i = 0; i < pageCount; i++) {
      final pageSize = _pageBounds[i].size;

      nextPoint = switch (widget.direction) {
        PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        PageViewDirection.down => nextPoint,
        PageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _pageBounds[i] = pageBounds;

      final spacing = widget.spacing;
      nextPoint = switch (widget.direction) {
        PageViewDirection.up => pageBounds.topLeft.translate(0, -spacing),
        PageViewDirection.left => pageBounds.topLeft.translate(-spacing, 0),
        PageViewDirection.down => pageBounds.bottomLeft.translate(0, spacing),
        PageViewDirection.right => pageBounds.topRight.translate(spacing, 0),
      };
    }
  }

  void glance(Rect viewRegion) {
    final pageInView = <int>[];
    for (int i = widget.pageCount - 1; i >= 0; i--) {
      final pageBounds = _pageBounds[i];
      if (pageBounds.overlaps(viewRegion)) {
        pageInView.add(i);
      }
    }

    if (pageInView.isNotEmpty) {
      final pageToLoad = Set<int>();
      for (final i in pageInView) {
        if (!_loadedWidgets.containsKey(i)) {
          pageToLoad.add(i);
        }
        // Inverted because we iterate in reverse earlier
        final firstPageVisible = pageInView.last;
        final lastPageVisible = pageInView.first;

        for (int p = 1; p <= widget.precacheAhead; p++) {
          final nextPage = lastPageVisible + p;
          if (nextPage >= 0 &&
              nextPage < widget.pageCount &&
              !_loadedWidgets.containsKey(nextPage)) {
            pageToLoad.add(nextPage);
          }
        }
        for (int p = 1; p <= widget.precacheBehind; p++) {
          final nextPage = firstPageVisible - p;
          if (nextPage >= 0 &&
              nextPage < widget.pageCount &&
              !_loadedWidgets.containsKey(nextPage)) {
            pageToLoad.add(nextPage);
          }
        }
      }
      if (pageToLoad.isNotEmpty) {
        for (final index in pageToLoad) {
          _loadedWidgets[index] = widget.pageBuilder(context, index);
        }
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.direction.isVertical ? _viewportSize.width : null,
      height: widget.direction.isHorizontal ? _viewportSize.height : null,
      child: Flex(
        direction: widget.direction.isVertical
            ? Axis.vertical
            : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: widget.spacing,
        children: [
          if (widget.direction.isReverse)
            for (int i = widget.pageCount - 1; i >= 0; i--)
              _buildPage(context, i)
          else
            for (int i = 0; i < widget.pageCount; i++) _buildPage(context, i),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return Builder(
      builder: (context) {
        return NotificationListener(
          onNotification: (event) {
            if (event is SizeChangedLayoutNotification) {
              _onPageSizeChanged(context, index);
              return true;
            }
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.maxPageSize.width,
                maxHeight: widget.maxPageSize.height,
              ),
              child:
                  _loadedWidgets[index] ??
                  SizedBox.fromSize(size: widget.initialPageSize),
            ),
          ),
        );
      },
    );
  }
}
