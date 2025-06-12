import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../manga_page_view.dart';
import 'widgets/cached_page.dart';

class ScrollInfo {
  final offset = ValueNotifier(Offset.zero);
  final zoomLevel = ValueNotifier(1.0);

  void dispose() {
    offset.dispose();
    zoomLevel.dispose();
  }

  void addListener(VoidCallback listener) {
    offset.addListener(listener);
    zoomLevel.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    offset.removeListener(listener);
    zoomLevel.removeListener(listener);
  }

  Rect transformZoom(Rect bounds, Size viewportSize) {
    // Formula to calculate desirable offset range depending on zoom level
    f(double v, double z) => (1 - 1 / z) * (v / 2);

    final paddingX = f(viewportSize.width, zoomLevel.value);
    final paddingY = f(viewportSize.height, zoomLevel.value);

    return Rect.fromLTRB(
      bounds.left - paddingX,
      bounds.top - paddingY,
      bounds.right + paddingX,
      bounds.bottom + paddingY,
    );
  }
}

class MangaPageContinuousView extends StatefulWidget {
  const MangaPageContinuousView({
    super.key,
    required this.controller,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
    required this.viewportSize,
    this.onPageChanged,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Size viewportSize;
  final Function(int index)? onPageChanged;

  @override
  State<MangaPageContinuousView> createState() =>
      _MangaPageContinuousViewState();
}

class _MangaPageContinuousViewState extends State<MangaPageContinuousView>
    with TickerProviderStateMixin {
  final _pageContainerKey = GlobalKey<MangaPageContainerState>();

  late final _flingXAnimation = AnimationController.unbounded(vsync: this);
  late final _flingYAnimation = AnimationController.unbounded(vsync: this);
  late final _offsetAnimation = AnimationController(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  late final _scrollInfo = ScrollInfo();

  bool _isZoomDragging = false;
  double? _zoomLevelOnTouch;
  Offset? _lastTouchPoint;
  int _currentPage = 0;

  VoidCallback? _offsetAnimationUpdateListener;
  VoidCallback? _zoomAnimationUpdateListener;

  @override
  void initState() {
    super.initState();
    _scrollInfo.offset.addListener(_onScrollOffsetChanged);
    widget.controller.pageIndexChangeRequest.addListener(
      _onPageIndexChangeRequest,
    );

    _scrollInfo.zoomLevel.value = widget.options.initialZoomLevel;

    _offsetAnimation.addListener(_onAnimateOffsetUpdate);
    _zoomAnimation.addListener(_onAnimateZoomUpdate);
  }

  @override
  void dispose() {
    _scrollInfo.offset.removeListener(_onScrollOffsetChanged);
    widget.controller.pageIndexChangeRequest.removeListener(
      _onPageIndexChangeRequest,
    );

    _flingXAnimation.dispose();
    _flingYAnimation.dispose();
    _zoomAnimation.dispose();
    _scrollInfo.dispose();

    _offsetAnimation.removeListener(_onAnimateOffsetUpdate);
    _zoomAnimation.removeListener(_onAnimateZoomUpdate);
    super.dispose();
  }

  MangaPageContainerState get containerState => _pageContainerKey.currentState!;

  Offset get offset => _scrollInfo.offset.value;
  double get zoomLevel => _scrollInfo.zoomLevel.value;
  PageViewDirection get direction => widget.options.direction;

  @override
  void didUpdateWidget(covariant MangaPageContinuousView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.options.direction != oldWidget.options.direction ||
        widget.options.scrollGravity != oldWidget.options.scrollGravity ||
        widget.options.centerPageOnEdge != oldWidget.options.centerPageOnEdge) {
      _stopFlingAnimation();

      if (widget.options.direction.isHorizontal &&
              oldWidget.options.direction.isVertical ||
          widget.options.direction.isVertical &&
              oldWidget.options.direction.isHorizontal) {
        // Flip offset on axis change
        _scrollInfo.offset.value = Offset(offset.dy, offset.dx);
      }

      Future.delayed(
        Duration(milliseconds: 100),
        () => _settlePageOffset(forceAllowOverscroll: true),
      );
    }
  }

  // Similar to clamp but
  double _limitBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value.clamp(limitA, limitB);
    } else {
      return 0;
    }
  }

  Size _calculateContainerSize() {
    final containerRenderBox =
        _pageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerRenderBox != null && containerRenderBox.hasSize) {
      return containerRenderBox.size;
    } else {
      return Size.zero;
    }
  }

  void _onPageIndexChangeRequest() {
    final targetPage = widget.controller.pageIndexChangeRequest.value;

    if (targetPage != null) {
      final targetOffset = containerState.pageIndexToOffset(
        targetPage,
        widget.options.scrollGravity,
      );

      Future.microtask(() => widget.onPageChanged?.call(targetPage));
      _animateOffsetChange(
        targetOffset: targetOffset,
        onEnd: () => widget.controller.pageIndexChangeRequest.value = null,
      );
    }
  }

  void _onScrollOffsetChanged() {
    if (_offsetAnimation.isAnimating) {
      return;
    }
    if (widget.controller.pageIndexChangeRequest.value != null) {
      return;
    }
    final showingPage = containerState
        .offsetToPageIndex(offset * zoomLevel, widget.options.scrollGravity)
        .clamp(0, widget.itemCount);

    if (showingPage != _currentPage) {
      _currentPage = showingPage;
      Future.microtask(() => widget.onPageChanged?.call(showingPage));
    }
  }

  void _handleTouch() {
    _stopFlingAnimation();

    _zoomLevelOnTouch = zoomLevel;
  }

  void _stopFlingAnimation() {
    _flingXAnimation.stop();
    _flingYAnimation.stop();
  }

  void _handleStartDrag(ScaleStartDetails details) {
    _stopFlingAnimation();

    _lastTouchPoint = details.localFocalPoint;
    _zoomLevelOnTouch = zoomLevel;
  }

  void _handlePanDrag(ScaleUpdateDetails details) {
    final deltaX = details.focalPointDelta.dx / zoomLevel;
    final deltaY = details.focalPointDelta.dy / zoomLevel;
    var newX =
        offset.dx + (direction == PageViewDirection.left ? deltaX : -deltaX);
    var newY =
        offset.dy + (direction == PageViewDirection.up ? deltaY : -deltaY);

    _scrollInfo.offset.value = _limitOffsetWithinBounds(
      Offset(newX, newY),
      allowHorizontalOverscroll:
          direction.isHorizontal && widget.options.mainAxisOverscroll ||
          direction.isVertical && widget.options.crossAxisOverscroll,
      allowVerticalOverscroll:
          direction.isVertical && widget.options.mainAxisOverscroll ||
          direction.isHorizontal && widget.options.crossAxisOverscroll,
    );
  }

  void _handleZoomDrag(ScaleUpdateDetails details) {
    // Drag up or down to change zoom level
    // Only Y positions will be considered

    final difference = details.localFocalPoint.dy - _lastTouchPoint!.dy;

    _scrollInfo.zoomLevel.value = (_zoomLevelOnTouch! + difference / 100).clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );
    _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
  }

  void _handleFling(ScaleEndDetails details) {
    _settlePageOffset(velocity: details.velocity.pixelsPerSecond / zoomLevel);
  }

  void _handlePinch(ScaleUpdateDetails details) {
    final newZoom = (_zoomLevelOnTouch! * details.scale).clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );

    _scrollInfo.zoomLevel.value = newZoom;
    _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
  }

  void _handleLift(ScaleEndDetails details) {
    if (details.pointerCount == 1) {
      _zoomLevelOnTouch = zoomLevel;
    }
    if (details.pointerCount == 0) {
      _zoomLevelOnTouch = null;
      _isZoomDragging = false;
      _lastTouchPoint = null;
    }
  }

  void _handleZoomDoubleTap() {
    final presetZoomLevels = [...widget.options.presetZoomLevels]..sort();

    if (presetZoomLevels.isEmpty) {
      // Default behavior if no preset levels are defined
      _animateZoomChange(targetLevel: 1.0);
      return;
    }

    double nextZoomLevel = presetZoomLevels.firstWhere(
      (level) => level > zoomLevel,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(targetLevel: nextZoomLevel);
  }

  void _handleMouseWheel(PointerScrollEvent event) {
    final scrollDelta = event.scrollDelta;

    // TODO: Handle macOS convention
    if (HardwareKeyboard.instance.isControlPressed) {
      final scrollAmount = -scrollDelta.dy * 0.002;
      _scrollInfo.zoomLevel.value = (zoomLevel + scrollAmount).clamp(
        widget.options.minZoomLevel,
        widget.options.maxZoomLevel,
      );
      _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
      return;
    }

    // Handle offset movement
    final newOffset = switch (HardwareKeyboard.instance.isShiftPressed) {
      true => offset.translate(
        scrollDelta.dy,
        0,
      ), // Control left-right movement
      false => offset + scrollDelta,
    };
    _stopFlingAnimation();
    _scrollInfo.offset.value = _limitOffsetWithinBounds(newOffset);
  }

  Rect _calculateScrollableRegion() {
    final containerSize = _calculateContainerSize();
    var rect = Rect.fromLTWH(
      0,
      0,
      containerSize.width - widget.viewportSize.width,
      containerSize.height - widget.viewportSize.height,
    );

    if (widget.options.centerPageOnEdge) {
      final viewportSize = widget.viewportSize;
      final containerState = _pageContainerKey.currentState!;
      final firstPageSize = containerState.getPageBounds(0).size;
      final lastPageSize = containerState
          .getPageBounds(widget.itemCount - 1)
          .size;

      if (direction.isVertical) {
        final topPadding =
            (viewportSize.height / zoomLevel - firstPageSize.height) / 2;
        final bottomPadding =
            (viewportSize.height / zoomLevel - lastPageSize.height) / 2;

        if (topPadding > 0) {
          rect = Rect.fromLTRB(
            rect.left,
            rect.top - topPadding,
            rect.right,
            rect.bottom,
          );
        }
        if (bottomPadding > 0) {
          rect = Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right,
            rect.bottom + bottomPadding,
          );
        }
      } else if (direction.isHorizontal) {
        final leftPadding =
            (viewportSize.width / zoomLevel - firstPageSize.width) / 2;
        final rightPadding =
            (viewportSize.width / zoomLevel - lastPageSize.width) / 2;

        if (leftPadding > 0) {
          rect = Rect.fromLTRB(
            rect.left - leftPadding,
            rect.top,
            rect.right,
            rect.bottom,
          );
        }
        if (rightPadding > 0) {
          rect = Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right + rightPadding,
            rect.bottom,
          );
        }
      }
    }

    return _scrollInfo.transformZoom(rect, widget.viewportSize);
  }

  Offset _limitOffsetWithinBounds(
    Offset offset, {
    bool allowVerticalOverscroll = false,
    bool allowHorizontalOverscroll = false,
  }) {
    var (x, y) = (offset.dx, offset.dy);

    final scrollableRegion = _calculateScrollableRegion();

    if (!allowHorizontalOverscroll) {
      x = _limitBound(x, scrollableRegion.left, scrollableRegion.right);
    }
    if (!allowVerticalOverscroll) {
      y = _limitBound(y, scrollableRegion.top, scrollableRegion.bottom);
    }

    return Offset(x, y);
  }

  void _settlePageOffset({
    Offset velocity = Offset.zero,
    bool forceAllowOverscroll = false,
  }) {
    void settleOnAxis({
      required double currentOffset,
      required double minOffset,
      required double maxOffset,
      required double velocity,
      required AnimationController flingAnimation,
      Function(double offset)? update,
    }) {
      // In case of zooming out
      final isZoomingOut = maxOffset < minOffset;

      onAnimationUpdate() {
        update?.call(flingAnimation.value);
        if (flingAnimation.isCompleted) {
          flingAnimation.removeListener(onAnimationUpdate);
        }
      }

      final simulation = BouncingScrollSimulation(
        position: currentOffset,
        velocity: -velocity,
        leadingExtent: !isZoomingOut ? minOffset : 0,
        trailingExtent: !isZoomingOut ? maxOffset : 0,
        spring: SpringDescription.withDampingRatio(
          mass: 0.5,
          stiffness: 100.0,
          ratio: 1.1,
        ),
        tolerance: Tolerance.defaultTolerance,
      );

      flingAnimation
        ..addListener(onAnimationUpdate)
        ..animateWith(simulation);
    }

    final scrollableRegion = _calculateScrollableRegion();

    settleOnAxis(
      currentOffset: offset.dx,
      velocity: direction == PageViewDirection.left
          ? -velocity.dx
          : velocity.dx,
      minOffset: scrollableRegion.left,
      maxOffset: scrollableRegion.right,
      flingAnimation: _flingXAnimation,
      update: (val) {
        var newX = val;
        if (!forceAllowOverscroll &&
            (direction.isVertical && !widget.options.crossAxisOverscroll ||
                direction.isHorizontal && !widget.options.mainAxisOverscroll)) {
          newX = _limitBound(
            newX,
            scrollableRegion.left,
            scrollableRegion.right,
          );
        }
        _scrollInfo.offset.value = Offset(newX, offset.dy);
      },
    );
    settleOnAxis(
      currentOffset: offset.dy,
      velocity: direction == PageViewDirection.up ? -velocity.dy : velocity.dy,
      minOffset: scrollableRegion.top,
      maxOffset: scrollableRegion.bottom,
      flingAnimation: _flingYAnimation,
      update: (val) {
        var newY = val;
        if (!forceAllowOverscroll &&
            (direction.isHorizontal && !widget.options.crossAxisOverscroll ||
                direction.isVertical && !widget.options.mainAxisOverscroll)) {
          newY = _limitBound(
            newY,
            scrollableRegion.top,
            scrollableRegion.bottom,
          );
        }
        _scrollInfo.offset.value = Offset(offset.dx, newY);
      },
    );
  }

  void _animateZoomChange({required double targetLevel}) {
    final currentLevel = zoomLevel;
    final zoomTween = Tween<double>(begin: currentLevel, end: targetLevel);
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeInOut),
    );

    _zoomAnimationUpdateListener = () {
      _scrollInfo.zoomLevel.value = animation.value;
      _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
      if (_zoomAnimation.isCompleted) {
        _settlePageOffset();
      }
    };

    _zoomAnimation
      ..drive(zoomTween)
      ..duration = Duration(milliseconds: 200)
      ..forward(from: 0);
  }

  void _animateOffsetChange({
    required Offset targetOffset,
    VoidCallback? onEnd,
  }) {
    final currentOffset = offset;
    final zoomTween = Tween<Offset>(
      begin: currentOffset,
      end: _limitOffsetWithinBounds(targetOffset),
    );
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _offsetAnimation, curve: Curves.easeInOut),
    );

    _offsetAnimationUpdateListener = () {
      _scrollInfo.offset.value = animation.value;
      if (_offsetAnimation.isCompleted) {
        _settlePageOffset();
        onEnd?.call();
      }
    };

    _offsetAnimation
      ..drive(zoomTween)
      ..duration = Duration(milliseconds: 200)
      ..forward(from: 0);
  }

  void _onAnimateOffsetUpdate() {
    _offsetAnimationUpdateListener?.call();
  }

  void _onAnimateZoomUpdate() {
    _zoomAnimationUpdateListener?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _handleMouseWheel(event);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                _handleTouch();
              },
              onScaleStart: (details) {
                _handleStartDrag(details);
              },
              onDoubleTapDown: (details) {
                _isZoomDragging = true;
              },
              onDoubleTap: () {
                _handleZoomDoubleTap();
                _isZoomDragging = false;
                _lastTouchPoint = null;
              },
              onScaleUpdate: (details) {
                if (_isZoomDragging) {
                  _handleZoomDrag(details);
                } else if (details.pointerCount == 2 && details.scale != 1) {
                  _handlePinch(details);
                } else {
                  _handlePanDrag(details);
                }
              },
              onScaleEnd: (details) {
                _handleLift(details);
                _handleFling(details);
              },
              child: ValueListenableBuilder(
                valueListenable: _scrollInfo.zoomLevel,
                builder: (context, zoomLevel, child) {
                  return Transform.scale(scale: zoomLevel, child: child);
                },
                child: ValueListenableBuilder(
                  valueListenable: _scrollInfo.offset,
                  builder: (context, offset, child) {
                    final alignment = switch (direction) {
                      PageViewDirection.up => Alignment.bottomLeft,
                      PageViewDirection.left => Alignment.topRight,
                      PageViewDirection.down => Alignment.topLeft,
                      PageViewDirection.right => Alignment.topLeft,
                    };

                    Offset resultOffset = switch (direction) {
                      PageViewDirection.up => Offset(offset.dx, -offset.dy),
                      PageViewDirection.left => Offset(-offset.dx, offset.dy),
                      PageViewDirection.down => offset,
                      PageViewDirection.right => offset,
                    };

                    return Transform.translate(
                      offset: -resultOffset,

                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        alignment: alignment,
                        child: child,
                      ),
                    );
                  },
                  child: MangaPageContainer(
                    key: _pageContainerKey,
                    scrollInfo: _scrollInfo,
                    viewportSize: widget.viewportSize,
                    options: widget.options,
                    itemCount: widget.itemCount,
                    itemBuilder: widget.itemBuilder,
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ValueListenableBuilder(
              valueListenable: _scrollInfo.zoomLevel,
              builder: (context, value, child) {
                return ValueListenableBuilder(
                  valueListenable: _scrollInfo.offset,
                  builder: (context, value, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offset: ${_scrollInfo.offset.value.dx.toStringAsFixed(2)}, ${_scrollInfo.offset.value.dy.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Zoom: ${_scrollInfo.zoomLevel.value.toStringAsFixed(3)}',
                        ),
                        Text('Container size: ${_calculateContainerSize()}'),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

@internal
class MangaPageContainer extends StatefulWidget {
  const MangaPageContainer({
    super.key,
    required this.scrollInfo,
    required this.viewportSize,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
  });

  final ScrollInfo scrollInfo;
  final Size viewportSize;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<MangaPageContainer> createState() => MangaPageContainerState();
}

class MangaPageContainerState extends State<MangaPageContainer> {
  Offset get offset => widget.scrollInfo.offset.value;
  double get zoomLevel => widget.scrollInfo.zoomLevel.value;
  PageViewDirection get direction => widget.options.direction;

  int _loadedPageStartIndex = 0;
  int _loadedPageEndIndex = 0;
  late List<Size> _loadedPageSize;
  late List<Rect> _loadedPageBounds;

  @override
  void initState() {
    super.initState();
    widget.scrollInfo.addListener(_updatePageVisibility);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadedPageSize = List.filled(
        widget.itemCount,
        widget.options.initialPageSize,
      );
      _loadedPageBounds = List.filled(widget.itemCount, Rect.zero);
      _refreshPageBounds();
    });
  }

  @override
  void dispose() {
    widget.scrollInfo.removeListener(_updatePageVisibility);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPageContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.direction != oldWidget.options.direction) {
      _refreshPageBounds();
    }
  }

  Rect getPageBounds(int pageIndex) {
    return _loadedPageBounds[pageIndex];
  }

  int offsetToPageIndex(Offset offset, PageViewGravity gravity) {
    Rect transform(Rect bounds) {
      return widget.scrollInfo.transformZoom(bounds, widget.viewportSize);
    }

    final viewportSize = widget.viewportSize;
    final viewportCenter = viewportSize.center(Offset.zero);

    final isBoundInRange = switch (widget.options.direction) {
      PageViewDirection.down =>
        (Rect b) =>
            gravity.select(
              start: b.top,
              center: b.center.dy - viewportCenter.dy,
              end: b.bottom - viewportSize.height,
            ) >
            offset.dy / zoomLevel,
      PageViewDirection.up =>
        (Rect b) =>
            gravity.select(
              start: -b.bottom,
              center: -b.center.dy - viewportCenter.dy,
              end: -b.top - viewportSize.height,
            ) >
            offset.dy / zoomLevel,
      PageViewDirection.right =>
        (Rect b) =>
            gravity.select(
              start: b.left,
              center: b.center.dx - viewportCenter.dx,
              end: b.right - viewportSize.width,
            ) >
            offset.dx / zoomLevel,
      PageViewDirection.left =>
        (Rect b) =>
            gravity.select(
              start: -b.right,
              center: -b.center.dx - viewportCenter.dx,
              end: -b.left - viewportSize.width,
            ) >
            offset.dx / zoomLevel,
    };

    int foundPageIndex = -1;

    for (Rect pageBounds in _loadedPageBounds.map(transform)) {
      if (isBoundInRange(pageBounds)) {
        break;
      }
      foundPageIndex += 1;
    }
    return foundPageIndex;
  }

  Offset pageIndexToOffset(int index, PageViewGravity gravity) {
    final pageBounds = widget.scrollInfo.transformZoom(
      _loadedPageBounds[index],
      widget.viewportSize,
    );
    final viewportSize = widget.viewportSize;
    final viewportCenter = viewportSize.center(Offset.zero);

    return switch (direction) {
      PageViewDirection.down => Offset(
        0,
        gravity.select(
          start: pageBounds.top,
          center: pageBounds.center.dy - viewportCenter.dy,
          end: pageBounds.bottom - viewportSize.height,
        ),
      ),
      PageViewDirection.up => Offset(
        0,
        gravity.select(
          start: -pageBounds.bottom,
          center: -pageBounds.center.dy - viewportCenter.dy,
          end: -pageBounds.top - viewportSize.height,
        ),
      ),
      PageViewDirection.right => Offset(
        gravity.select(
          start: pageBounds.left,
          center: pageBounds.center.dx - viewportCenter.dx,
          end: pageBounds.right - viewportSize.width,
        ),
        0,
      ),
      PageViewDirection.left => Offset(
        gravity.select(
          start: -pageBounds.right,
          center: -pageBounds.center.dx - viewportCenter.dx,
          end: -pageBounds.left - viewportSize.width,
        ),
        0,
      ),
    };
  }

  void _onPageSizeChanged(BuildContext context, int pageIndex) {
    final pageRenderBox = context.findRenderObject() as RenderBox;
    final pageSize = pageRenderBox.size;
    _loadedPageSize[pageIndex] = pageSize;
    _refreshPageBounds();
  }

  void _refreshPageBounds() {
    Offset nextPoint = Offset.zero;
    for (int i = 0; i < widget.itemCount; i++) {
      final pageSize = _loadedPageSize[i];

      nextPoint = switch (widget.options.direction) {
        PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        PageViewDirection.down => nextPoint,
        PageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _loadedPageBounds[i] = pageBounds;

      nextPoint = switch (widget.options.direction) {
        PageViewDirection.up => pageBounds.topLeft,
        PageViewDirection.left => pageBounds.topLeft,
        PageViewDirection.down => pageBounds.bottomLeft,
        PageViewDirection.right => pageBounds.topRight,
      };
    }

    _updatePageVisibility();
  }

  void _updatePageVisibility() {
    final viewportSize = widget.viewportSize;

    final nextVisiblePageIndex = offsetToPageIndex(
      (offset * zoomLevel).translate(viewportSize.width, viewportSize.height),
      PageViewGravity.start,
    );

    if (nextVisiblePageIndex > _loadedPageEndIndex) {
      setState(() {
        _loadedPageEndIndex = nextVisiblePageIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContainer(context);
  }

  Widget _buildContainer(BuildContext context) {
    return SizedBox(
      width: direction.isVertical ? widget.viewportSize.width : null,
      height: direction.isHorizontal ? widget.viewportSize.height : null,
      child: Flex(
        direction: direction.isVertical ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.options.direction.isReverse)
            for (int i = widget.itemCount - 1; i >= 0; i--)
              _buildPage(context, i)
          else
            for (int i = 0; i < widget.itemCount; i++) _buildPage(context, i),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return Builder(
      key: ValueKey(index),
      builder: (context) {
        final cacheRangeEnd = min(
          _loadedPageEndIndex + widget.options.precacheOverhead,
          widget.itemCount - 1,
        );
        final cacheRangeStart = max(0, 0);

        final isPageVisible =
            index >= cacheRangeStart && index <= cacheRangeEnd;

        return NotificationListener(
          onNotification: (event) {
            if (event is SizeChangedLayoutNotification) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _onPageSizeChanged(context, index);
              });
              return true;
            }
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.options.maxPageSize.width,
                maxHeight: widget.options.maxPageSize.height,
              ),
              child: CachedPage(
                builder: (context) => widget.itemBuilder(context, index),
                visible: isPageVisible,
                initialSize: widget.options.initialPageSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
