import 'package:flutter/material.dart';
import 'package:manga_page_view/manga_page_view.dart';

import 'manga_page_container.dart';

class MangaPageView extends StatelessWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.itemCount,
    required this.itemBuilder,
  });

  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MangaPageContinuousView(
          options: options,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          viewportSize: constraints.biggest,
        );
      },
    );
  }
}

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

  Rect scrollableRegion(Size containerSize, Size viewportSize) {
    // Formula to calculate desirable offset range depending on zoom level
    f(double v, double z) => (1 - 1 / z) * (v / 2);

    final scrollPaddingX = f(viewportSize.width, zoomLevel.value);
    final scrollPaddingY = f(viewportSize.height, zoomLevel.value);

    final scrollableRegion = Rect.fromLTRB(
      -scrollPaddingX,
      -scrollPaddingY,
      containerSize.width - viewportSize.width + scrollPaddingX,
      containerSize.height - viewportSize.height + scrollPaddingY,
    );

    return scrollableRegion;
  }
}

class MangaPageContinuousView extends StatefulWidget {
  const MangaPageContinuousView({
    super.key,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
    required this.viewportSize,
  });

  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Size viewportSize;

  @override
  State<MangaPageContinuousView> createState() =>
      _MangaPageContinuousViewState();
}

class _MangaPageContinuousViewState extends State<MangaPageContinuousView>
    with TickerProviderStateMixin {
  final _pageContainerKey = GlobalKey();

  late final _flingAnimationX = AnimationController.unbounded(vsync: this);
  late final _flingAnimationY = AnimationController.unbounded(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  late final _scrollInfo = ScrollInfo();

  bool _zoomDragMode = false;
  double? _zoomLevelOnTouch;
  Offset? _lastTouchPoint;

  @override
  void initState() {
    super.initState();
    _scrollInfo.zoomLevel.value = widget.options.initialZoomLevel;
  }

  @override
  void dispose() {
    _flingAnimationX.dispose();
    _flingAnimationY.dispose();
    _zoomAnimation.dispose();
    _scrollInfo.dispose();
    super.dispose();
  }

  Offset get offset => _scrollInfo.offset.value;
  double get zoomLevel => _scrollInfo.zoomLevel.value;

  PageViewDirection get direction => widget.options.direction;

  @override
  void didUpdateWidget(covariant MangaPageContinuousView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.options.direction != oldWidget.options.direction) {
      _stopFlingAnimation();
      _scrollInfo.offset.value = Offset.zero;
      Future.delayed(Duration(milliseconds: 100), () => _settlePageOffset());
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

  Size _getContainerSize() {
    final containerRenderBox =
        _pageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerRenderBox != null && containerRenderBox.hasSize) {
      return containerRenderBox.size;
    } else {
      return Size.zero;
    }
  }

  void _handleTouch() {
    _stopFlingAnimation();

    _zoomLevelOnTouch = zoomLevel;
  }

  void _stopFlingAnimation() {
    _flingAnimationX.stop();
    _flingAnimationY.stop();
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

    _scrollInfo.offset.value = _limitOffsetWithinBounds(Offset(newX, newY));
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
      (level) => level > zoomLevel,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(targetLevel: nextZoomLevel);
  }

  Offset _limitOffsetWithinBounds(Offset offset) {
    var (x, y) = (offset.dx, offset.dy);

    final scrollableRegion = _scrollInfo.scrollableRegion(
      _getContainerSize(),
      widget.viewportSize,
    );

    if (direction.isVertical && !widget.options.crossAxisOverscroll ||
        direction.isHorizontal && !widget.options.mainAxisOverscroll) {
      x = _limitBound(x, scrollableRegion.left, scrollableRegion.right);
    }
    if (direction.isHorizontal && !widget.options.crossAxisOverscroll ||
        direction.isVertical && !widget.options.mainAxisOverscroll) {
      y = _limitBound(y, scrollableRegion.top, scrollableRegion.bottom);
    }
    ;

    return Offset(x, y);
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
      // In case of zooming out
      final isZoomingOut = maxOffset < minOffset;

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
        ..addListener(() {
          update?.call(flingAnimation.value);
        })
        ..animateWith(simulation);
    }

    final scrollableRegion = _scrollInfo.scrollableRegion(
      _getContainerSize(),
      widget.viewportSize,
    );

    settleOnAxis(
      currentOffset: offset.dx,
      velocity: direction == PageViewDirection.left
          ? -velocity.dx
          : velocity.dx,
      minOffset: scrollableRegion.left,
      maxOffset: scrollableRegion.right,
      flingAnimation: _flingAnimationX,
      update: (val) {
        var newX = val;
        if (direction.isVertical && !widget.options.crossAxisOverscroll ||
            direction.isHorizontal && !widget.options.mainAxisOverscroll) {
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
      flingAnimation: _flingAnimationY,
      update: (val) {
        var newY = val;
        if (direction.isHorizontal && !widget.options.crossAxisOverscroll ||
            direction.isVertical && !widget.options.mainAxisOverscroll) {
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
      CurvedAnimation(parent: _zoomAnimation, curve: Easing.standard),
    );
    _zoomAnimation
      ..drive(zoomTween)
      ..addListener(() {
        _scrollInfo.zoomLevel.value = animation.value;
        _scrollInfo.offset.value = _limitOffsetWithinBounds(offset);
        if (_zoomAnimation.status == AnimationStatus.completed) {
          _settlePageOffset();
        }
      })
      ..duration = Duration(milliseconds: 200)
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
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
                        Text('Container size: ${_getContainerSize()}'),
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
