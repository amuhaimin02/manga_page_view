import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;

enum PanelAlignment {
  top,
  bottom,
  left,
  right;

  bool get isInverted => this == bottom || this == right;
}

class MangaPageInteractivePanel extends StatefulWidget {
  const MangaPageInteractivePanel({
    super.key,
    required this.child,
    required this.viewportSize, // TODO: Remove?
    required this.initialZoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.presetZoomLevels,
    required this.verticalOverscroll,
    required this.horizontalOverscroll,
    required this.alignment,
    required this.zoomOnFocalPoint,
    required this.zoomOvershoot,
    this.onInteract,
  });

  final Widget child;
  final Size viewportSize;
  final double initialZoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final List<double> presetZoomLevels;
  final bool verticalOverscroll;
  final bool horizontalOverscroll;
  final PanelAlignment alignment;
  final bool zoomOnFocalPoint;
  final bool zoomOvershoot;
  final Function(ScrollInfo info)? onInteract;

  @override
  State<MangaPageInteractivePanel> createState() =>
      MangaPageInteractivePanelState();
}

class ScrollInfo {
  final Offset offset;
  final double zoomLevel;
  final Rect scrollableRegion;

  ScrollInfo(this.offset, this.zoomLevel, this.scrollableRegion);
}

class MangaPageInteractivePanelState extends State<MangaPageInteractivePanel>
    with TickerProviderStateMixin {
  late final _childKey = GlobalKey();

  late final _flingXAnimation = AnimationController.unbounded(vsync: this);
  late final _flingYAnimation = AnimationController.unbounded(vsync: this);
  late final _offsetAnimation = AnimationController(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);

  VoidCallback? _offsetAnimationUpdateListener;
  VoidCallback? _zoomAnimationUpdateListener;

  final _activePointers = <int, VelocityTracker>{};
  final _activePositions = <int, Offset>{};
  Duration? _lastTouchTimeStamp = null;
  bool _isDoubleTap = false;
  bool _isZoomDragging = false;
  Offset? _startTouchPoint;
  double? _lastPinchDistance;
  double? _lastScaleRatio;
  static const _trackpadDeviceId = 99;

  late final _offset = ValueNotifier(Offset.zero);
  late final _zoomLevel = ValueNotifier(1.0);
  late final _viewport = ValueNotifier(Size.zero);
  late final _childSize = ValueNotifier(Size.zero);

  late final _scrollRegionChange = Listenable.merge([
    _zoomLevel,
    _viewport,
    _childSize,
  ]);
  Rect _scrollableRegion = Rect.zero;

  Duration _sinceLastTouch(Duration current) => _lastTouchTimeStamp != null
      ? current - _lastTouchTimeStamp!
      : Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _offset.addListener(_onOffsetChanged);
    _zoomLevel.addListener(_onZoomLevelChanged);
    _offsetAnimation.addListener(_onAnimateOffsetUpdate);
    _zoomAnimation.addListener(_onAnimateZoomUpdate);
    _zoomLevel.value = widget.initialZoomLevel;

    _scrollRegionChange.addListener(_updateScrollableRegion);
  }

  @override
  void dispose() {
    _scrollRegionChange.removeListener(_updateScrollableRegion);
    _offset.removeListener(_onOffsetChanged);
    _zoomLevel.removeListener(_onZoomLevelChanged);
    _offset.dispose();
    _zoomLevel.dispose();
    _viewport.dispose();
    _childSize.dispose();

    _flingXAnimation.dispose();
    _flingYAnimation.dispose();
    _zoomAnimation.dispose();

    _offsetAnimation.removeListener(_onAnimateOffsetUpdate);
    _zoomAnimation.removeListener(_onAnimateZoomUpdate);

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPageInteractivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    _viewport.value = widget.viewportSize;
    _updateChildSize();

    if (widget.alignment != oldWidget.alignment) {
      _stopFlingAnimation();

      Future.delayed(
        Duration(milliseconds: 100),
        () => _settlePageOffset(forceAllowOverscroll: true),
      );
    }
  }

  void jumpTo(Offset offset) {
    _stopFlingAnimation();
    _offset.value = offset;
  }

  void _onOffsetChanged() {
    widget.onInteract?.call(
      ScrollInfo(_offset.value, _zoomLevel.value, _scrollableRegion),
    );
  }

  void _onZoomLevelChanged() {
    widget.onInteract?.call(
      ScrollInfo(_offset.value, _zoomLevel.value, _scrollableRegion),
    );
  }

  // Similar to clamp but
  double _limitBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value.clamp(limitA, limitB);
    } else {
      return 0;
    }
  }

  void _handleTouch(Offset position) {
    _stopFlingAnimation();
    _startTouchPoint = position;
  }

  void _stopFlingAnimation() {
    _flingXAnimation.stop();
    _flingYAnimation.stop();
  }

  void _handlePanDrag(Offset delta) {
    final deltaX = delta.dx / _zoomLevel.value;
    final deltaY = delta.dy / _zoomLevel.value;
    var newX = _offset.value.dx - deltaX;
    var newY = _offset.value.dy - deltaY;

    _offset.value = _limitOffsetWithinBounds(
      Offset(newX, newY),
      allowHorizontalOverscroll: widget.horizontalOverscroll,
      allowVerticalOverscroll: widget.verticalOverscroll,
    );
  }

  double _resistZoomOvershoot(double currentZoom) {
    final minZoom = widget.minZoomLevel;
    final maxZoom = widget.maxZoomLevel;

    if (currentZoom > maxZoom) {
      final excess = currentZoom - maxZoom;
      final resistanceFactor = 1 / maxZoom;
      final resisted =
          maxZoom +
          (1 - math.exp(-excess * resistanceFactor)) / resistanceFactor;
      return resisted;
    } else if (currentZoom < minZoom) {
      final excess = minZoom - currentZoom;
      final resistanceFactor = 1 / minZoom;
      final resisted =
          minZoom -
          (1 - math.exp(-excess * resistanceFactor)) / resistanceFactor;
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
    final viewportCenter = _viewport.value.center(Offset.zero);
    final focalPointFromCenter = focalPoint - viewportCenter;

    final zoomDifference = finalZoom - initialZoom;

    final moveOffset =
        Offset(
          focalPointFromCenter.dx * zoomDifference,
          focalPointFromCenter.dy * zoomDifference,
        ) /
        initialZoom;
    return _limitOffsetWithinBounds(
      _offset.value + moveOffset / finalZoom,
      allowHorizontalOverscroll: widget.horizontalOverscroll,
      allowVerticalOverscroll: widget.verticalOverscroll,
    );
  }

  void _handleZoomDrag(Offset delta) {
    final currentZoom = _zoomLevel.value;

    // Compute proposed zoom level
    final zoomSensitivity = 1.005;
    double newZoom = currentZoom * math.pow(zoomSensitivity, delta.dy);

    if (!widget.zoomOvershoot) {
      // Hard clamp if overshoot disabled
      newZoom = newZoom.clamp(widget.minZoomLevel, widget.maxZoomLevel);
    } else {
      // Apply resistance on overshoot
      newZoom = _resistZoomOvershoot(newZoom);
    }

    _zoomLevel.value = newZoom;

    if (widget.zoomOnFocalPoint) {
      _offset.value = _calculateOffsetAfterZoom(
        _startTouchPoint!,
        currentZoom,
        newZoom,
      );
    } else {
      _offset.value = _limitOffsetWithinBounds(_offset.value);
    }
  }

  void _handleFling(Velocity velocity) {
    _settlePageOffset(velocity: velocity.pixelsPerSecond / _zoomLevel.value);
    _settleZoom();
  }

  void _handlePinch(Offset focalPoint, double scaleRatioChange) {
    final currentZoom = _zoomLevel.value;
    double newZoom = currentZoom * scaleRatioChange;

    if (!widget.zoomOvershoot) {
      newZoom = newZoom.clamp(widget.minZoomLevel, widget.maxZoomLevel);
    } else {
      newZoom = _resistZoomOvershoot(newZoom);
    }

    _zoomLevel.value = newZoom;

    if (widget.zoomOnFocalPoint) {
      _offset.value = _calculateOffsetAfterZoom(
        focalPoint,
        currentZoom,
        newZoom,
      );
    } else {
      _offset.value = _limitOffsetWithinBounds(_offset.value);
    }
  }

  void _handleLift() {
    if (_activePointers.isEmpty) {
      _isZoomDragging = false;
      _startTouchPoint = null;
      _lastPinchDistance = null;
      _lastScaleRatio = null;
    }
  }

  void _handleZoomDoubleTap(Offset touchPoint) {
    final presetZoomLevels = [...widget.presetZoomLevels]..sort();

    if (presetZoomLevels.isEmpty) {
      // Default behavior if no preset levels are defined
      _animateZoomChange(targetLevel: 1.0, focalPoint: touchPoint);
      return;
    }

    double nextZoomLevel = presetZoomLevels.firstWhere(
      (level) => level > _zoomLevel.value,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(targetLevel: nextZoomLevel, focalPoint: touchPoint);
  }

  void _handleMouseWheel(Offset focalPoint, Offset delta) {
    // TODO: Handle macOS convention
    if (HardwareKeyboard.instance.isControlPressed) {
      final currentZoom = _zoomLevel.value;
      final scrollAmount = -delta.dy * 0.002;
      final newZoom = (_zoomLevel.value + scrollAmount);
      _zoomLevel.value = newZoom.clamp(
        widget.minZoomLevel,
        widget.maxZoomLevel,
      );

      if (widget.zoomOnFocalPoint) {
        _offset.value = _calculateOffsetAfterZoom(
          focalPoint,
          currentZoom,
          newZoom,
        );
      } else {
        _offset.value = _limitOffsetWithinBounds(_offset.value);
      }
      return;
    }

    // Handle offset movement
    final newOffset = switch (HardwareKeyboard.instance.isShiftPressed) {
      true => _offset.value.translate(
        delta.dy,
        0,
      ), // Control left-right movement
      false => _offset.value + delta,
    };
    _stopFlingAnimation();
    _offset.value = _limitOffsetWithinBounds(newOffset);
  }

  void _updateScrollableRegion() {
    Rect transformZoom(Rect bounds) {
      // Formula to calculate desirable offset range depending on zoom level
      f(double v, double z) => (1 - 1 / z) * (v / 2);

      final paddingX = f(_viewport.value.width, _zoomLevel.value);
      final paddingY = f(_viewport.value.height, _zoomLevel.value);

      return Rect.fromLTRB(
        bounds.left - paddingX,
        bounds.top - paddingY,
        bounds.right + paddingX,
        bounds.bottom + paddingY,
      );
    }

    final rect = transformZoom(
      Rect.fromLTRB(
        0,
        0,
        _childSize.value.width - _viewport.value.width,
        _childSize.value.height - _viewport.value.height,
      ),
    );

    var (left, top, right, bottom) = (
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
    );

    if (left > right) {
      left = 0;
      right = 0;
    }
    if (top > bottom) {
      top = 0;
      bottom = 0;
    }
    if (widget.alignment == PanelAlignment.right) {
      left = -left;
      right = -right;
    } else if (widget.alignment == PanelAlignment.bottom) {
      top = -top;
      bottom = -bottom;
    }

    _scrollableRegion = Rect.fromLTRB(left, top, right, bottom);

    // final containerSize = containerState.manager.containerSize;
    // var rect = Rect.fromLTWH(
    //   0,
    //   0,
    //   containerSize.width - _viewport.width,
    //   containerSize.height - _viewport.height,
    // );
    //
    // if (widget.options.centerPageOnEdge) {
    //   final viewportSize = _viewport;
    //   final firstPageSize = containerState.manager.getBounds(0).size;
    //   final lastPageSize = containerState.manager
    //       .getBounds(widget.itemCount - 1)
    //       .size;
    //
    //   if (direction.isVertical) {
    //     final topPadding =
    //         (viewportSize.height / zoomLevel - firstPageSize.height) / 2;
    //     final bottomPadding =
    //         (viewportSize.height / zoomLevel - lastPageSize.height) / 2;
    //
    //     if (topPadding > 0) {
    //       rect = Rect.fromLTRB(
    //         rect.left,
    //         rect.top - topPadding,
    //         rect.right,
    //         rect.bottom,
    //       );
    //     }
    //     if (bottomPadding > 0) {
    //       rect = Rect.fromLTRB(
    //         rect.left,
    //         rect.top,
    //         rect.right,
    //         rect.bottom + bottomPadding,
    //       );
    //     }
    //   } else if (direction.isHorizontal) {
    //     final leftPadding =
    //         (viewportSize.width / zoomLevel - firstPageSize.width) / 2;
    //     final rightPadding =
    //         (viewportSize.width / zoomLevel - lastPageSize.width) / 2;
    //
    //     if (leftPadding > 0) {
    //       rect = Rect.fromLTRB(
    //         rect.left - leftPadding,
    //         rect.top,
    //         rect.right,
    //         rect.bottom,
    //       );
    //     }
    //     if (rightPadding > 0) {
    //       rect = Rect.fromLTRB(
    //         rect.left,
    //         rect.top,
    //         rect.right + rightPadding,
    //         rect.bottom,
    //       );
    //     }
    //   }
    // }

    // return _scrollInfo.transformZoom(rect, _viewport);
  }

  Offset _limitOffsetWithinBounds(
    Offset offset, {
    bool allowVerticalOverscroll = false,
    bool allowHorizontalOverscroll = false,
  }) {
    var (x, y) = (offset.dx, offset.dy);

    if (!allowHorizontalOverscroll) {
      x = _limitBound(x, _scrollableRegion.left, _scrollableRegion.right);
    }
    if (!allowVerticalOverscroll) {
      y = _limitBound(y, _scrollableRegion.top, _scrollableRegion.bottom);
    }

    return Offset(x, y);
  }

  void _settleZoom() {
    final settledZoomLevel = _zoomLevel.value.clamp(
      widget.minZoomLevel,
      widget.maxZoomLevel,
    );
    _animateZoomChange(targetLevel: settledZoomLevel, handleOffset: false);
  }

  void _settlePageOffset({
    Offset velocity = Offset.zero,
    bool forceAllowOverscroll = false,
  }) {
    void settleOnAxis({
      required double currentOffset,
      required (double, double) bounds,
      required double velocity,
      required AnimationController flingAnimation,
      Function(double offset)? update,
    }) {
      onAnimationUpdate() {
        update?.call(flingAnimation.value);
        if (flingAnimation.isCompleted) {
          flingAnimation.removeListener(onAnimationUpdate);
        }
      }

      final simulation = BouncingScrollSimulation(
        position: currentOffset,
        velocity: velocity,
        leadingExtent: bounds.$1 > bounds.$2 ? bounds.$2 : bounds.$1,
        trailingExtent: bounds.$1 > bounds.$2 ? bounds.$1 : bounds.$2,
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

    settleOnAxis(
      currentOffset: _offset.value.dx,
      velocity: -velocity.dx,
      bounds: (_scrollableRegion.left, _scrollableRegion.right),
      flingAnimation: _flingXAnimation,
      update: (val) {
        var newX = val;
        if (!forceAllowOverscroll && !widget.horizontalOverscroll) {
          newX = _limitBound(
            newX,
            _scrollableRegion.left,
            _scrollableRegion.right,
          );
        }
        _offset.value = Offset(newX, _offset.value.dy);
      },
    );
    settleOnAxis(
      currentOffset: _offset.value.dy,
      velocity: -velocity.dy,
      bounds: (_scrollableRegion.top, _scrollableRegion.bottom),
      flingAnimation: _flingYAnimation,
      update: (val) {
        var newY = val;
        if (!forceAllowOverscroll && !widget.verticalOverscroll) {
          newY = _limitBound(
            newY,
            _scrollableRegion.top,
            _scrollableRegion.bottom,
          );
        }
        _offset.value = Offset(_offset.value.dx, newY);
      },
    );
  }

  void _updateChildSize() {
    _childSize.value =
        ((_childKey.currentContext!.findRenderObject() as RenderBox)).size;
  }

  void _animateZoomChange({
    required double targetLevel,
    bool handleOffset = true,
    Offset? focalPoint = null,
  }) {
    final currentLevel = _zoomLevel.value;
    final zoomTween = Tween<double>(begin: currentLevel, end: targetLevel);
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeInOut),
    );

    _zoomAnimationUpdateListener = () {
      final currentZoom = _zoomLevel.value;
      final newZoom = animation.value;
      _zoomLevel.value = newZoom;
      if (handleOffset) {
        if (focalPoint != null && widget.zoomOnFocalPoint) {
          _offset.value = _calculateOffsetAfterZoom(
            focalPoint,
            currentZoom,
            newZoom,
          );
        } else {
          _offset.value = _limitOffsetWithinBounds(_offset.value);
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
    final currentOffset = _offset.value;
    final zoomTween = Tween<Offset>(
      begin: currentOffset,
      end: _limitOffsetWithinBounds(targetOffset),
    );
    final animation = zoomTween.animate(
      CurvedAnimation(parent: _offsetAnimation, curve: Curves.easeInOut),
    );

    _offsetAnimationUpdateListener = () {
      _offset.value = animation.value;
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _activePointers[event.device] = VelocityTracker.withKind(event.kind)
          ..addPosition(event.timeStamp, event.position);
        ;
        _activePositions[event.device] = event.position;

        _handleTouch(event.localPosition);

        if (event.device == 0 &&
            _sinceLastTouch(event.timeStamp) < Duration(milliseconds: 300)) {
          _isDoubleTap = true;
          _isZoomDragging = true;
        }

        // Primary touch
        if (event.device == 0) {
          _lastTouchTimeStamp = event.timeStamp;
        }
      },
      onPointerUp: (event) {
        final tracker = _activePointers[event.device]!;
        _activePointers.remove(event.device);
        _activePositions.remove(event.device);

        if (_activePointers.isEmpty) {
          if (_isDoubleTap &&
              event.device == 0 &&
              _sinceLastTouch(event.timeStamp) < Duration(milliseconds: 300)) {
            if (_isDoubleTap) {
              _handleZoomDoubleTap(_startTouchPoint!);
            }
          } else {
            final magnitude = tracker.getVelocity().pixelsPerSecond.distance;
            if (magnitude > 0 ||
                _sinceLastTouch(event.timeStamp) >
                    Duration(milliseconds: 300)) {
              _handleFling(tracker.getVelocity());
            }
          }

          _isDoubleTap = false;
          _handleLift();
        }
      },
      onPointerMove: (event) {
        _activePointers[event.device]!.addPosition(
          event.timeStamp,
          event.position,
        );
        _activePositions[event.device] = event.position;
        if (_isDoubleTap) {
          _isDoubleTap = false;
        }

        if (_isZoomDragging) {
          _handleZoomDrag(event.localDelta);
          return;
        }

        if (_activePointers.containsKey(0) && _activePointers.containsKey(1)) {
          final (firstPoint, secondPoint) = (
            _activePositions[0]!,
            _activePositions[1]!,
          );
          final focalPoint = (firstPoint + secondPoint) / 2;
          final distance = (firstPoint - secondPoint).distance;

          final distanceRatio = _lastPinchDistance != null
              ? distance / _lastPinchDistance!
              : 1.0;

          _lastPinchDistance = distance;

          _handlePinch(focalPoint, distanceRatio);
        }

        _handlePanDrag(event.localDelta);
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleMouseWheel(event.localPosition, event.scrollDelta);
        }
      },
      onPointerPanZoomStart: (event) {
        _activePointers[_trackpadDeviceId] = VelocityTracker.withKind(
          event.kind,
        );
        _handleTouch(event.localPosition);
      },
      onPointerPanZoomUpdate: (event) {
        if (event.scale != 1) {
          final scaleRatio = _lastScaleRatio != null
              ? event.scale / _lastScaleRatio!
              : 1.0;
          _handlePinch(event.localPosition, scaleRatio);
          _lastScaleRatio = event.scale;
        }

        _activePointers[_trackpadDeviceId]!.addPosition(
          event.timeStamp,
          event.localPan,
        );
        _handlePanDrag(event.localPanDelta);
      },
      onPointerPanZoomEnd: (event) {
        final tracker = _activePointers[_trackpadDeviceId]!;
        _activePointers.remove(_trackpadDeviceId);
        _handleLift();
        _handleFling(tracker.getVelocity());
      },
      child: ValueListenableBuilder(
        valueListenable: _zoomLevel,
        builder: (context, zoomLevel, child) {
          return Transform.scale(scale: zoomLevel, child: child);
        },
        child: ValueListenableBuilder(
          valueListenable: _offset,
          builder: (context, offset, child) {
            return Transform.translate(
              offset: -offset,

              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: switch (widget.alignment) {
                  PanelAlignment.top => Alignment.topLeft,
                  PanelAlignment.left => Alignment.topLeft,
                  PanelAlignment.bottom => Alignment.bottomLeft,
                  PanelAlignment.right => Alignment.topRight,
                },
                child: child,
              ),
            );
          },
          child: NotificationListener(
            onNotification: (event) {
              if (event is SizeChangedLayoutNotification) {
                _updateChildSize();
                return true;
              }
              return false;
            },
            child: SizeChangedLayoutNotifier(
              child: SizedBox(key: _childKey, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
