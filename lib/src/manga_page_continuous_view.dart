import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../manga_page_view.dart';
import 'widgets/cached_page.dart';

class _ScrollInfo {
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

class _MangaPageContinuousViewState extends State<MangaPageContinuousView>
    with TickerProviderStateMixin {
  final _pageContainerKey = GlobalKey<MangaPageContainerState>();

  late final _flingXAnimation = AnimationController.unbounded(vsync: this);
  late final _flingYAnimation = AnimationController.unbounded(vsync: this);
  late final _offsetAnimation = AnimationController(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  late final _scrollInfo = _ScrollInfo();

  bool _isZoomDragging = false;
  double? _zoomLevelOnTouch;
  Offset? _startTouchPoint;
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
    widget.controller.fractionChangeRequest.addListener(
      _onFractionChangeRequest,
    );
    widget.controller.offsetChangeRequest.addListener(_onOffsetChangeRequest);

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
    widget.controller.fractionChangeRequest.removeListener(
      _onFractionChangeRequest,
    );
    widget.controller.offsetChangeRequest.removeListener(
      _onOffsetChangeRequest,
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

      if (widget.options.direction != oldWidget.options.direction) {
        // Direction has changed. Retain current page index
        Future.microtask(() {
          _scrollInfo.offset.value = containerState.pageIndexToOffset(
            _currentPage,
            widget.options.scrollGravity,
          );
        });
      }

      _sendScrollProgress();

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

  void _onPageIndexChangeRequest() {
    final targetPage = widget.controller.pageIndexChangeRequest.value;

    if (targetPage != null) {
      final targetOffset = containerState.pageIndexToOffset(
        targetPage,
        widget.options.scrollGravity,
      );

      Future.microtask(() => widget.onPageChange?.call(targetPage));
      _animateOffsetChange(
        targetOffset: targetOffset,
        onEnd: () => widget.controller.pageIndexChangeRequest.value = null,
      );
    }
  }

  void _onFractionChangeRequest() {
    final targetValue = widget.controller.fractionChangeRequest.value;

    if (targetValue != null) {
      final scrollableRegion = _calculateScrollableRegion();

      _stopFlingAnimation();
      _scrollInfo.offset.value = direction.isVertical
          ? Offset(
              offset.dx,
              targetValue * scrollableRegion.height + scrollableRegion.top,
            )
          : Offset(
              (targetValue * scrollableRegion.width + scrollableRegion.left),
              offset.dy,
            );
      widget.controller.offsetChangeRequest.value = null;
    }
  }

  void _onOffsetChangeRequest() {
    final targetValue = widget.controller.offsetChangeRequest.value;

    if (targetValue != null) {
      final scrollableRegion = _calculateScrollableRegion();

      _stopFlingAnimation();
      _scrollInfo.offset.value = direction.isVertical
          ? Offset(offset.dx, targetValue + scrollableRegion.top)
          : Offset(targetValue + scrollableRegion.left, offset.dy);
      widget.controller.offsetChangeRequest.value = null;
    }
  }

  void _onScrollOffsetChanged() {
    if (widget.onProgressChange != null) {
      _sendScrollProgress();
    }

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
      Future.microtask(() => widget.onPageChange?.call(showingPage));
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

    _startTouchPoint = details.localFocalPoint;
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

  double _resistZoomOvershoot(double currentZoom) {
    final minZoom = widget.options.minZoomLevel;
    final maxZoom = widget.options.maxZoomLevel;

    if (currentZoom > maxZoom) {
      final excess = currentZoom - maxZoom;
      final resistanceFactor = 1 / maxZoom;
      final resisted =
          maxZoom + (1 - exp(-excess * resistanceFactor)) / resistanceFactor;
      return resisted;
    } else if (currentZoom < minZoom) {
      final excess = minZoom - currentZoom;
      final resistanceFactor = 1 / minZoom;
      final resisted =
          minZoom - (1 - exp(-excess * resistanceFactor)) / resistanceFactor;
      return resisted;
    } else {
      return currentZoom;
    }
  }

  Offset _calculateOffsetAfterZoom(
    Offset focalPoint,
    double initialZoom,
    double finalZoom,
  ) {
    final viewportCenter = widget.viewportSize.center(Offset.zero);
    final focalPointFromCenter = focalPoint - viewportCenter;

    final zoomDifference = finalZoom - initialZoom;

    final moveOffset =
        Offset(
          focalPointFromCenter.dx * zoomDifference,
          focalPointFromCenter.dy * zoomDifference,
        ) /
        initialZoom;
    return _limitOffsetWithinBounds(offset + moveOffset / finalZoom);
  }

  void _handleZoomDrag(ScaleUpdateDetails details) {
    final difference = details.localFocalPoint.dy - _startTouchPoint!.dy;
    final currentZoom = zoomLevel;

    // Compute proposed zoom level
    final zoomSensitivity = 1.005;
    double newZoom = _zoomLevelOnTouch! * pow(zoomSensitivity, difference);

    if (!widget.options.zoomOvershoot) {
      // Hard clamp if overshoot disabled
      newZoom = newZoom.clamp(
        widget.options.minZoomLevel,
        widget.options.maxZoomLevel,
      );
    } else {
      // Apply resistance on overshoot
      newZoom = _resistZoomOvershoot(newZoom);
    }

    _scrollInfo.zoomLevel.value = newZoom;

    if (widget.options.zoomOnFocalPoint) {
      _scrollInfo.offset.value = _calculateOffsetAfterZoom(
        _startTouchPoint!,
        currentZoom,
        newZoom,
      );
    } else {
      _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
    }
  }

  void _handleFling(ScaleEndDetails details) {
    _settlePageOffset(velocity: details.velocity.pixelsPerSecond / zoomLevel);
    _settleZoom();
  }

  void _handlePinch(ScaleUpdateDetails details) {
    final currentZoom = zoomLevel;
    double newZoom = _zoomLevelOnTouch! * details.scale;

    if (!widget.options.zoomOvershoot) {
      newZoom = newZoom.clamp(
        widget.options.minZoomLevel,
        widget.options.maxZoomLevel,
      );
    } else {
      newZoom = _resistZoomOvershoot(newZoom);
    }

    _scrollInfo.zoomLevel.value = newZoom;

    if (widget.options.zoomOnFocalPoint) {
      _scrollInfo.offset.value = _calculateOffsetAfterZoom(
        details.localFocalPoint,
        currentZoom,
        newZoom,
      );
    } else {
      _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
    }
  }

  void _handleLift(ScaleEndDetails details) {
    if (details.pointerCount == 1) {
      _zoomLevelOnTouch = zoomLevel;
    }
    if (details.pointerCount == 0) {
      _zoomLevelOnTouch = null;
      _isZoomDragging = false;
      _startTouchPoint = null;
    }
  }

  void _handleZoomDoubleTap() {
    final presetZoomLevels = [...widget.options.presetZoomLevels]..sort();

    if (presetZoomLevels.isEmpty) {
      // Default behavior if no preset levels are defined
      _animateZoomChange(targetLevel: 1.0, focalPoint: _startTouchPoint);
      return;
    }

    double nextZoomLevel = presetZoomLevels.firstWhere(
      (level) => level > zoomLevel,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(
      targetLevel: nextZoomLevel,
      focalPoint: _startTouchPoint,
    );
  }

  void _handleMouseWheel(PointerScrollEvent event) {
    final scrollDelta = event.scrollDelta;
    final cursorPosition = event.localPosition;

    // TODO: Handle macOS convention
    if (HardwareKeyboard.instance.isControlPressed) {
      final currentZoom = zoomLevel;
      final scrollAmount = -scrollDelta.dy * 0.002;
      final newZoom = (zoomLevel + scrollAmount);
      _scrollInfo.zoomLevel.value = newZoom.clamp(
        widget.options.minZoomLevel,
        widget.options.maxZoomLevel,
      );

      if (widget.options.zoomOnFocalPoint) {
        _scrollInfo.offset.value = _calculateOffsetAfterZoom(
          cursorPosition,
          currentZoom,
          newZoom,
        );
      } else {
        _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
      }
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
    final containerSize = containerState.manager.containerSize;
    var rect = Rect.fromLTWH(
      0,
      0,
      containerSize.width - widget.viewportSize.width,
      containerSize.height - widget.viewportSize.height,
    );

    if (widget.options.centerPageOnEdge) {
      final viewportSize = widget.viewportSize;
      final firstPageSize = containerState.manager.getBounds(0).size;
      final lastPageSize = containerState.manager
          .getBounds(widget.itemCount - 1)
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

  void _settleZoom() {
    final settledZoomLevel = zoomLevel.clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );
    _animateZoomChange(targetLevel: settledZoomLevel, handleOffset: false);
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

  void _sendScrollProgress() {
    Future.microtask(() {
      final scrollableRegion = _calculateScrollableRegion();
      final currentPixels = direction.isVertical
          ? offset.dy - scrollableRegion.top
          : offset.dx - scrollableRegion.left;
      final totalPixels = direction.isVertical
          ? scrollableRegion.height
          : scrollableRegion.width;

      widget.onProgressChange?.call(
        MangaPageViewScrollProgress(
          currentPage: _currentPage,
          totalPages: widget.itemCount,
          currentPixels: currentPixels.clamp(0, totalPixels),
          totalPixels: totalPixels,
          fraction: (currentPixels / totalPixels).clamp(0, 1),
        ),
      );
    });
  }

  void _animateZoomChange({
    required double targetLevel,
    bool handleOffset = true,
    Offset? focalPoint = null,
  }) {
    final currentLevel = zoomLevel;
    final zoomTween = Tween<double>(begin: currentLevel, end: targetLevel);
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeInOut),
    );

    _zoomAnimationUpdateListener = () {
      final currentZoom = zoomLevel;
      final newZoom = animation.value;
      _scrollInfo.zoomLevel.value = newZoom;
      if (handleOffset) {
        if (focalPoint != null && widget.options.zoomOnFocalPoint) {
          _scrollInfo.offset.value = _calculateOffsetAfterZoom(
            focalPoint,
            currentZoom,
            newZoom,
          );
        } else {
          _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
        }
        if (_zoomAnimation.isCompleted) {
          _settlePageOffset();
        }
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
                _startTouchPoint = details.localPosition;
              },
              onDoubleTap: () {
                _handleZoomDoubleTap();
                _isZoomDragging = false;
                _startTouchPoint = null;
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
                        Text(
                          'Container size: ${containerState.manager.containerSize}',
                        ),
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

  final _ScrollInfo scrollInfo;
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

  int _loadedPageEndIndex = 0;
  final manager = _MangaPageContainerRegionManager();

  @override
  void initState() {
    super.initState();
    widget.scrollInfo.addListener(_updatePageVisibility);
    manager.addListener(_onContainerSizeUpdate);
    manager.setup(
      widget.itemCount,
      widget.options.initialPageSize,
      widget.options.spacing,
      widget.options.direction,
    );
  }

  @override
  void dispose() {
    widget.scrollInfo.removeListener(_updatePageVisibility);
    manager.removeListener(_onContainerSizeUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPageContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.direction != oldWidget.options.direction) {
      manager.reorient(widget.options.direction);
    }
  }

  void _onContainerSizeUpdate() {
    _updatePageVisibility();
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

    for (Rect pageBounds in manager.allBounds.map(transform)) {
      if (isBoundInRange(pageBounds)) {
        break;
      }
      foundPageIndex += 1;
    }
    return foundPageIndex;
  }

  Offset pageIndexToOffset(int index, PageViewGravity gravity) {
    final pageBounds = widget.scrollInfo.transformZoom(
      manager.getBounds(index),
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
    manager.updatePage(pageIndex, pageSize);
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
        spacing: widget.options.spacing,
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

class _MangaPageContainerRegionManager extends ChangeNotifier {
  int _pageCount = 0;
  PageViewDirection _direction = PageViewDirection.down;

  List<Rect> _pageBounds = [];
  Size _containerSize = Size.zero;
  double _spacing = 0;

  void setup(
    int totalPages,
    Size initialSize,
    double spacing,
    PageViewDirection direction,
  ) {
    _pageCount = totalPages;
    _spacing = spacing;
    _direction = direction;
    _pageBounds = List.filled(totalPages, Offset.zero & initialSize);
    _recalculate();
  }

  Rect getBounds(int pageIndex) {
    return _pageBounds[pageIndex];
  }

  void updatePage(int pageIndex, Size pageSize) {
    _pageBounds[pageIndex] = Offset.zero & pageSize;
    _recalculate();
  }

  void reorient(PageViewDirection newDirection) {
    _direction = newDirection;
    _recalculate();
  }

  Size get containerSize => _containerSize;

  Iterable<Rect> get allBounds => _pageBounds;

  void _recalculate() {
    Offset nextPoint = Offset.zero;
    for (int i = 0; i < _pageCount; i++) {
      final pageSize = _pageBounds[i].size;

      nextPoint = switch (_direction) {
        PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        PageViewDirection.down => nextPoint,
        PageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _pageBounds[i] = pageBounds;

      nextPoint = switch (_direction) {
        PageViewDirection.up => pageBounds.topLeft.translate(0, -_spacing),
        PageViewDirection.left => pageBounds.topLeft.translate(-_spacing, 0),
        PageViewDirection.down => pageBounds.bottomLeft.translate(0, _spacing),
        PageViewDirection.right => pageBounds.topRight.translate(_spacing, 0),
      };
    }

    final overallBounds = _pageBounds.first.expandToInclude(_pageBounds.last);
    _containerSize = overallBounds.size;

    notifyListeners();
  }
}
