import 'package:flutter/material.dart';
import 'package:manga_page_view/manga_page_view.dart';

import 'manga_page_container.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView.builder({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.itemCount,
    required this.itemBuilder,
  });

  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView>
    with TickerProviderStateMixin {
  final _pageContainerKey = GlobalKey();

  late final _flingAnimationX = AnimationController.unbounded(vsync: this);
  late final _flingAnimationY = AnimationController.unbounded(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  late var _scrollOffset = ValueNotifier(Offset.zero);
  late var _zoomLevel = ValueNotifier(1.0);

  bool _zoomDragMode = false;
  double? _zoomLevelOnTouch;
  Offset? _lastTouchPoint;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _flingAnimationX.dispose();
    _flingAnimationY.dispose();
    _zoomAnimation.dispose();
    _scrollOffset.dispose();
    _zoomLevel.dispose();
    super.dispose();
  }

  bool get isScrollingVertically =>
      widget.options.scrollDirection == Axis.vertical;
  bool get isScrollingHorizontally =>
      widget.options.scrollDirection == Axis.horizontal;

  Rect get scrollableRegionOffset {
    // TODO: Optimize

    // Formula to calculate desirable offset range depending on zoom level
    f(double v, double z) => (1 - 1 / z) * (v / 2);

    final scrollPaddingX = f(viewportSize.width, _zoomLevel.value);
    final scrollPaddingY = f(viewportSize.height, _zoomLevel.value);

    final scrollableRegion = Rect.fromLTRB(
      -scrollPaddingX,
      -scrollPaddingY,
      containerSize.width - viewportSize.width + scrollPaddingX,
      containerSize.height - viewportSize.height + scrollPaddingY,
    );

    return scrollableRegion;
  }

  // Similar to clamp but
  double _limitBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value.clamp(limitA, limitB);
    } else {
      return 0;
    }
  }

  @override
  void didUpdateWidget(covariant MangaPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool scrollDirectionChanged = false;
    bool itemOrderChanged = false;

    if (widget.options.scrollDirection != oldWidget.options.scrollDirection) {
      scrollDirectionChanged = true;
      _stopFlingAnimation();
      // Swap main & cross axis
      _scrollOffset.value = Offset(
        _scrollOffset.value.dy,
        _scrollOffset.value.dx,
      );
    }

    if (widget.options.reverseItemOrder != oldWidget.options.reverseItemOrder) {
      itemOrderChanged = true;
      _stopFlingAnimation();
      // Flip axis
      _scrollOffset.value = -_scrollOffset.value;
    }

    if (scrollDirectionChanged || itemOrderChanged) {
      Future.delayed(Duration(milliseconds: 100), () => _settlePageOffset());
    }
  }

  Size get containerSize =>
      (_pageContainerKey.currentContext!.findRenderObject() as RenderBox).size;

  Size get viewportSize => (context.findRenderObject() as RenderBox).size;

  void _handleTouch() {
    _stopFlingAnimation();

    _zoomLevelOnTouch = _zoomLevel.value;
  }

  void _stopFlingAnimation() {
    _flingAnimationX.stop();
    _flingAnimationY.stop();
  }

  void _handleStartDrag(ScaleStartDetails details) {
    _stopFlingAnimation();

    _lastTouchPoint = details.localFocalPoint;
    _zoomLevelOnTouch = _zoomLevel.value;
  }

  void _handlePanDrag(ScaleUpdateDetails details) {
    var newX =
        _scrollOffset.value.dx -
        (details.focalPointDelta.dx / _zoomLevel.value);
    var newY =
        _scrollOffset.value.dy -
        (details.focalPointDelta.dy / _zoomLevel.value);

    // Limit scrolling to the container's bounds if required
    if (isScrollingVertically && !widget.options.crossAxisOverscroll ||
        isScrollingHorizontally && !widget.options.mainAxisOverscroll) {
      newX = _limitBound(
        newX,
        scrollableRegionOffset.left,
        scrollableRegionOffset.right,
      );
    }
    if (isScrollingHorizontally && !widget.options.crossAxisOverscroll ||
        isScrollingVertically && !widget.options.mainAxisOverscroll) {
      newY = _limitBound(
        newY,
        scrollableRegionOffset.top,
        scrollableRegionOffset.bottom,
      );
    }

    _scrollOffset.value = Offset(newX, newY);
  }

  void _handleZoomDrag(ScaleUpdateDetails details) {
    // Drag up or down to change zoom level
    // Only Y positions will be considered

    final difference = details.localFocalPoint.dy - _lastTouchPoint!.dy;

    _zoomLevel.value = (_zoomLevelOnTouch! + difference / 100).clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );
  }

  void _handleFling(ScaleEndDetails details) {
    _settlePageOffset(
      velocity: details.velocity.pixelsPerSecond / _zoomLevel.value,
    );
  }

  void _handlePinch(ScaleUpdateDetails details) {
    final newZoom = (_zoomLevelOnTouch! * details.scale).clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );

    _zoomLevel.value = newZoom;
  }

  void _handleLift(ScaleEndDetails details) {
    if (details.pointerCount == 1) {
      _zoomLevelOnTouch = _zoomLevel.value;
    }
    if (details.pointerCount == 0) {
      _zoomLevelOnTouch = null;
      _zoomDragMode = false;
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
      (level) => level > _zoomLevel.value,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(targetLevel: nextZoomLevel);
  }

  void _settlePageOffset({Offset velocity = Offset.zero}) {
    void settleOnAxis({
      required double currentOffset,
      required double minOffset,
      required double maxOffset,
      required double velocity,
      required AnimationController flingAnimation,
      Function(double offset)? update,
    }) {
      final reverseOrderFactor = widget.options.reverseItemOrder ? -1 : 1;

      // In case of zooming out
      final isZoomingOut = maxOffset < minOffset;

      final simulation = BouncingScrollSimulation(
        position: currentOffset * reverseOrderFactor,
        velocity: velocity * reverseOrderFactor,
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
        ..addListener(() {
          update?.call(flingAnimation.value * reverseOrderFactor);
        })
        ..animateWith(simulation);
    }

    final scrollableRegion = scrollableRegionOffset;

    settleOnAxis(
      currentOffset: _scrollOffset.value.dx,
      velocity: -velocity.dx,
      minOffset: scrollableRegion.left,
      maxOffset: scrollableRegion.right,
      flingAnimation: _flingAnimationX,
      update: (val) {
        var newX = val;
        if (isScrollingVertically && !widget.options.crossAxisOverscroll ||
            isScrollingHorizontally && !widget.options.mainAxisOverscroll) {
          newX = _limitBound(
            newX,
            scrollableRegion.left,
            scrollableRegion.right,
          );
        }
        return _scrollOffset.value = Offset(newX, _scrollOffset.value.dy);
      },
    );
    settleOnAxis(
      currentOffset: _scrollOffset.value.dy,
      velocity: -velocity.dy,
      minOffset: scrollableRegion.top,
      maxOffset: scrollableRegion.bottom,
      flingAnimation: _flingAnimationY,
      update: (val) {
        var newY = val;
        if (isScrollingHorizontally && !widget.options.crossAxisOverscroll ||
            isScrollingVertically && !widget.options.mainAxisOverscroll) {
          newY = _limitBound(
            newY,
            scrollableRegion.top,
            scrollableRegion.bottom,
          );
        }
        return _scrollOffset.value = Offset(_scrollOffset.value.dx, newY);
      },
    );
  }

  void _animateZoomChange({required double targetLevel}) {
    final currentLevel = _zoomLevel.value;
    final zoomTween = Tween<double>(begin: currentLevel, end: targetLevel);
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Easing.standard),
    );
    _zoomAnimation
      ..drive(zoomTween)
      ..addListener(() {
        _zoomLevel.value = animation.value;
        if (_zoomAnimation.status == AnimationStatus.completed) {
          _settlePageOffset();
        }
      })
      ..duration = Duration(milliseconds: 200)
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            _handleTouch();
          },
          onScaleStart: (details) {
            _handleStartDrag(details);
          },
          onDoubleTapDown: (details) {
            _zoomDragMode = true;
          },
          onDoubleTap: () {
            _handleZoomDoubleTap();
            _zoomDragMode = false;
            _lastTouchPoint = null;
          },
          onScaleUpdate: (details) {
            if (_zoomDragMode) {
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
            valueListenable: _zoomLevel,
            builder: (context, zoomLevel, child) {
              return Transform.scale(scale: zoomLevel, child: child);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ValueListenableBuilder(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, child) {
                    final boundWidth =
                        widget.options.scrollDirection == Axis.vertical
                        ? constraints.maxWidth
                        : null;
                    final boundHeight =
                        widget.options.scrollDirection == Axis.horizontal
                        ? constraints.maxHeight
                        : null;

                    if (!widget.options.reverseItemOrder) {
                      // Normal top-down or left-to-right layout
                      return Positioned(
                        left: -offset.dx,
                        top: -offset.dy,

                        width: boundWidth,
                        height: boundHeight,
                        child: child!,
                      );
                    } else {
                      if (widget.options.scrollDirection == Axis.horizontal) {
                        // Right-to-left layout
                        return Positioned(
                          right: offset.dx,
                          top: -offset.dy,

                          width: boundWidth,
                          height: boundHeight,
                          child: child!,
                        );
                      } else {
                        // Bottom-up layout
                        return Positioned(
                          left: -offset.dx,
                          bottom: offset.dy,

                          width: boundWidth,
                          height: boundHeight,
                          child: child!,
                        );
                      }
                    }
                  },
                  child: MangaPageContainer(
                    key: _pageContainerKey,
                    scrollOffset: _scrollOffset,
                    viewportSize: constraints.biggest,
                    options: widget.options,
                    itemCount: widget.itemCount,
                    itemBuilder: widget.itemBuilder,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
