import 'package:flutter/material.dart';
import 'package:manga_page_view/manga_page_view.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.children,
  });

  final MangaPageViewOptions options;
  final List<Widget> children;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView>
    with TickerProviderStateMixin {
  final _pageContainerKey = GlobalKey();

  late final _flingAnimationX = AnimationController.unbounded(vsync: this);
  late final _flingAnimationY = AnimationController.unbounded(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  late var _offset = Offset.zero;

  double _zoomLevel = 1.0;
  bool _zoomDragMode = false;

  double? _zoomLevelOnTouch;
  Offset? _lastTouchPoint;

  @override
  void dispose() {
    _flingAnimationX.dispose();
    _flingAnimationY.dispose();
    _zoomAnimation.dispose();
    super.dispose();
  }

  Size _getBoundingSize(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    return renderBox.size;
  }

  void _handleTouch() {
    _zoomLevelOnTouch = _zoomLevel;
  }

  void _handleStartDrag(ScaleStartDetails details) {
    // Stop currently running fling action
    _flingAnimationX.stop();
    _flingAnimationY.stop();

    _lastTouchPoint = details.localFocalPoint;
    _zoomLevelOnTouch = _zoomLevel;
  }

  void _handlePanDrag(ScaleUpdateDetails details) {
    var newX = _offset.dx - (details.focalPointDelta.dx / _zoomLevel);
    var newY = _offset.dy - (details.focalPointDelta.dy / _zoomLevel);
    setState(() {
      _offset = Offset(newX, newY);
    });
  }

  void _handleZoomDrag(ScaleUpdateDetails details) {
    // Drag up or down to change zoom level
    // Only Y positions will be considered

    final difference = details.localFocalPoint.dy - _lastTouchPoint!.dy;

    setState(() {
      _zoomLevel = (_zoomLevelOnTouch! + difference / 100).clamp(
        widget.options.minZoomLevel,
        widget.options.maxZoomLevel,
      );
    });
  }

  void _handleFling(ScaleEndDetails details) {
    _settlePageOffset(velocity: details.velocity.pixelsPerSecond);
  }

  void _handlePinch(ScaleUpdateDetails details) {
    final newZoom = (_zoomLevelOnTouch! * details.scale).clamp(
      widget.options.minZoomLevel,
      widget.options.maxZoomLevel,
    );

    setState(() {
      _zoomLevel = newZoom;
    });
  }

  void _handleLift(ScaleEndDetails details) {
    if (details.pointerCount == 1) {
      _zoomLevelOnTouch = _zoomLevel;
    }
    if (details.pointerCount == 0) {
      _zoomLevelOnTouch = null;
      _zoomDragMode = false;
      _lastTouchPoint = null;
    }
  }

  void _handleZoomDoubleTap() {
    if (_zoomLevel == 1) {
      _animateZoomChange(targetLevel: 3);
    } else {
      _animateZoomChange(targetLevel: 1);
    }
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
      // In case of zooming out
      final isZoomingOut = maxOffset < minOffset;

      final simulation = BouncingScrollSimulation(
        position: currentOffset,
        velocity: velocity,
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

    final containerSize = _getBoundingSize(_pageContainerKey.currentContext!);
    final viewportSize = _getBoundingSize(context);

    // Formula to calculate desirable offset range depending on zoom level
    f(double v, double z) => (1 - 1 / z) * (v / 2);

    final scrollPaddingX = f(viewportSize.width, _zoomLevel);
    final scrollPaddingY = f(viewportSize.height, _zoomLevel);

    final scrollableRegion = Rect.fromLTRB(
      -scrollPaddingX,
      -scrollPaddingY,
      containerSize.width - viewportSize.width + scrollPaddingX,
      containerSize.height - viewportSize.height + scrollPaddingY,
    );

    doScrollAxis(
      currentOffset: _offset.dx,
      velocity: -velocity.dx,
      minOffset: scrollableRegion.left,
      maxOffset: scrollableRegion.right,
      flingAnimation: _flingAnimationX,
      update: (val) => setState(() {
        _offset = Offset(val, _offset.dy);
      }),
    );
    doScrollAxis(
      currentOffset: _offset.dy,
      velocity: -velocity.dy,
      minOffset: scrollableRegion.top,
      maxOffset: scrollableRegion.bottom,
      flingAnimation: _flingAnimationY,
      update: (val) => setState(() {
        _offset = Offset(_offset.dx, val);
      }),
    );
  }

  void _animateZoomChange({required double targetLevel}) {
    final currentLevel = _zoomLevel;
    final zoomTween = Tween<double>(begin: currentLevel, end: targetLevel);
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Easing.standard),
    );
    _zoomAnimation
      ..drive(zoomTween)
      ..addListener(() {
        setState(() {
          _zoomLevel = animation.value;
        });
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
            child: Transform.scale(
              scale: _zoomLevel,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -_offset.dx,
                    top: -_offset.dy,
                    width: constraints.maxWidth,
                    child: Column(
                      key: _pageContainerKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < widget.children.length; i++)
                          _buildPage(context, i),
                      ],
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

  Widget _buildPage(BuildContext context, int index) {
    final page = widget.children[index];
    return FittedBox(fit: BoxFit.contain, child: page);
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
                Text(
                  'Offset: (${_offset.dx.toStringAsFixed(2)}, ${_offset.dy.toStringAsFixed(2)})\n'
                  'Zoom drag: $_zoomDragMode',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    IconButton(
                      onPressed: () {
                        _flingAnimationX.stop();
                        _flingAnimationY.stop();
                        setState(() {
                          _zoomLevel = 1.0;
                          _offset = Offset.zero;
                        });
                      },
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                ),
                Slider(
                  value: _zoomLevel,
                  min: widget.options.minZoomLevel,
                  max: widget.options.maxZoomLevel,
                  onChanged: (val) {
                    setState(() {
                      _zoomLevel = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
