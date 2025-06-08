import 'package:flutter/material.dart';
import 'package:manga_page_view/manga_page_view.dart';

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

  late var _offset = ValueNotifier(Offset.zero);
  late var _zoomLevel = ValueNotifier(1.0);

  bool _zoomDragMode = false;
  double? _zoomLevelOnTouch;
  Offset? _lastTouchPoint;

  @override
  void dispose() {
    _flingAnimationX.dispose();
    _flingAnimationY.dispose();
    _zoomAnimation.dispose();
    _offset.dispose();
    _zoomLevel.dispose();
    super.dispose();
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
      _offset.value = Offset(_offset.value.dy, _offset.value.dx);
    }

    if (widget.options.reverseItemOrder != oldWidget.options.reverseItemOrder) {
      itemOrderChanged = true;
      _stopFlingAnimation();
      // Flip axis
      _offset.value = -_offset.value;
    }

    if (scrollDirectionChanged || itemOrderChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _settlePageOffset());
    }
  }

  Size _getBoundingSize(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    return renderBox.size;
  }

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
        _offset.value.dx - (details.focalPointDelta.dx / _zoomLevel.value);
    var newY =
        _offset.value.dy - (details.focalPointDelta.dy / _zoomLevel.value);

    _offset.value = Offset(newX, newY);
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
    void doScrollAxis({
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

    final containerSize = _getBoundingSize(_pageContainerKey.currentContext!);
    final viewportSize = _getBoundingSize(context);

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

    doScrollAxis(
      currentOffset: _offset.value.dx,
      velocity: -velocity.dx,
      minOffset: scrollableRegion.left,
      maxOffset: scrollableRegion.right,
      flingAnimation: _flingAnimationX,
      update: (val) => _offset.value = Offset(val, _offset.value.dy),
    );
    doScrollAxis(
      currentOffset: _offset.value.dy,
      velocity: -velocity.dy,
      minOffset: scrollableRegion.top,
      maxOffset: scrollableRegion.bottom,
      flingAnimation: _flingAnimationY,
      update: (val) => _offset.value = Offset(_offset.value.dx, val),
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
            } else if (details.pointerCount == 2) {
              _handlePinch(details);
            } else if (details.pointerCount == 1) {
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
                  valueListenable: _offset,
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
                  child: _MangaPageContainer(
                    key: _pageContainerKey,
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

class _MangaPageContainer extends StatelessWidget {
  const _MangaPageContainer({
    super.key,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
  });

  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: options.scrollDirection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.reverseItemOrder)
          for (int i = itemCount - 1; i >= 0; i--) _buildPage(context, i)
        else
          for (int i = 0; i < itemCount; i++) _buildPage(context, i),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    final page = itemBuilder(context, index);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: options.maxItemSize.width,
        maxHeight: options.maxItemSize.height,
      ),
      child: FittedBox(fit: BoxFit.contain, child: page),
    );
  }
}
