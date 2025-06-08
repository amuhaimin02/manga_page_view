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

  // TODO: Temporary
  late var _scrollDirection = widget.options.scrollDirection;
  Axis get scrollDirection => _scrollDirection;
  late var _reverseItemOrder = widget.options.reverseItemOrder;
  bool get reverseItemOrder => _reverseItemOrder;

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
      final reverseOrderFactor = reverseItemOrder ? -1 : 1;

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
    return _buildDebugPanel(
      context: context,
      child: LayoutBuilder(
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
                      final boundWidth = scrollDirection == Axis.vertical
                          ? constraints.maxWidth
                          : null;
                      final boundHeight = scrollDirection == Axis.horizontal
                          ? constraints.maxHeight
                          : null;

                      if (!reverseItemOrder) {
                        // Normal top-down or left-to-right layout
                        return Positioned(
                          left: -offset.dx,
                          top: -offset.dy,

                          width: boundWidth,
                          height: boundHeight,
                          child: child!,
                        );
                      } else {
                        if (scrollDirection == Axis.horizontal) {
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
                      itemCount: widget.itemCount,
                      itemBuilder: widget.itemBuilder,
                      scrollDirection: scrollDirection,
                      reverseItemOrder: reverseItemOrder,
                      maxItemSize: widget.options.maxItemSize,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebugPanel({
    required BuildContext context,
    required Widget child,
  }) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.all(8),
            color: Colors.black54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    IconButton(
                      onPressed: () {
                        _stopFlingAnimation();

                        _zoomLevel.value = 1.0;
                        _offset.value = Offset.zero;
                      },
                      icon: Icon(Icons.refresh),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _reverseItemOrder = !reverseItemOrder;
                          _stopFlingAnimation();
                          _offset.value = -_offset.value;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _settlePageOffset();
                          });
                        });
                      },
                      icon: Icon(
                        reverseItemOrder ? Icons.move_up : Icons.move_down,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (scrollDirection == Axis.vertical) {
                            _scrollDirection = Axis.horizontal;
                          } else {
                            _scrollDirection = Axis.vertical;
                          }
                        });

                        _stopFlingAnimation();
                        _offset.value = Offset(
                          _offset.value.dy,
                          _offset.value.dx,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _settlePageOffset();
                        });
                      },
                      icon: Icon(
                        scrollDirection == Axis.vertical
                            ? Icons.swap_horiz
                            : Icons.swap_vert,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MangaPageContainer extends StatelessWidget {
  const _MangaPageContainer({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.scrollDirection,
    required this.reverseItemOrder,
    required this.maxItemSize,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Axis scrollDirection;
  final bool reverseItemOrder;
  final Size maxItemSize;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: scrollDirection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reverseItemOrder)
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
        maxWidth: maxItemSize.width,
        maxHeight: maxItemSize.height,
      ),
      child: FittedBox(fit: BoxFit.contain, child: page),
    );
  }
}
