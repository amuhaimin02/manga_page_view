import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;

import 'viewport_change.dart';

enum PanelAlignment { top, bottom, left, right }

class MangaPageInteractivePanel extends StatefulWidget {
  const MangaPageInteractivePanel({
    super.key,
    required this.child,
    required this.initialZoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.presetZoomLevels,
    required this.verticalOverscroll,
    required this.horizontalOverscroll,
    required this.alignment,
    required this.zoomOnFocalPoint,
    required this.zoomOvershoot,
    this.onScroll,
  });

  final Widget child;
  final double initialZoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final List<double> presetZoomLevels;
  final bool verticalOverscroll;
  final bool horizontalOverscroll;
  final PanelAlignment alignment;
  final bool zoomOnFocalPoint;
  final bool zoomOvershoot;
  final Function(Offset offset, double zoomLevel)? onScroll;

  @override
  State<MangaPageInteractivePanel> createState() =>
      MangaPageInteractivePanelState();
}

class _DoubleTapDetector {
  static const _durationThreshold = Duration(milliseconds: 300);
  static const _distanceThreshold = 40.0;

  _DoubleTapDetector();

  Duration? _firstTapTimestamp;
  Duration? _secondTapTimestamp;
  Offset? _firstTapPosition;
  Offset? _secondTapPosition;

  void registerTap(Duration timestamp, Offset position) {
    if (_firstTapTimestamp != null &&
        timestamp - _firstTapTimestamp! > _durationThreshold) {
      reset();
    }
    if (_secondTapTimestamp != null &&
        timestamp - _secondTapTimestamp! > _durationThreshold) {
      reset();
    }

    if (_firstTapTimestamp == null) {
      _firstTapTimestamp = timestamp;
      _firstTapPosition = position;
    } else if (_secondTapTimestamp == null) {
      _secondTapTimestamp = timestamp;
      _secondTapPosition = position;
    }
  }

  void registerUntap(Duration timestamp, Offset position) {
    if (_firstTapTimestamp != null &&
        timestamp - _firstTapTimestamp! > _durationThreshold) {
      reset();
    }
  }

  void reset() {
    _firstTapTimestamp = null;
    _secondTapTimestamp = null;
    _firstTapPosition = null;
    _secondTapPosition = null;
  }

  bool isTriggered(Duration timestamp) {
    if (_firstTapTimestamp == null || _secondTapTimestamp == null) {
      return false;
    }

    if (timestamp - _secondTapTimestamp! > _durationThreshold) {
      return false;
    }

    final duration = _secondTapTimestamp! - _firstTapTimestamp!;
    final distance = (_firstTapPosition! - _secondTapPosition!).distance;

    return duration < _durationThreshold && distance < _distanceThreshold;
  }

  bool willTrigger(Duration timestamp) {
    return _firstTapTimestamp != null && _secondTapTimestamp == null;
  }
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
  final _doubleTapDetector = _DoubleTapDetector();
  bool _isZoomDragging = false;
  Offset? _startTouchPoint;
  double? _startPinchDistance;
  double? _startZoomLevel;
  static const _trackpadDeviceId = 99;

  late final _readyToDisplay = ValueNotifier(false);
  late final _offset = ValueNotifier(Offset.zero);
  late final _zoomLevel = ValueNotifier(widget.initialZoomLevel);
  late final _childSize = ValueNotifier(Size.zero);
  late final _viewport = ValueNotifier(Size.zero);
  late final _viewportSizeProvider = ViewportSizeProvider.of(context);

  late final _scrollRegionChange = Listenable.merge([_zoomLevel, _viewport]);

  Rect _scrollableRegion = Rect.zero;

  Rect get scrollableRegion => _scrollableRegion;

  bool get _isFlinging =>
      _flingXAnimation.isAnimating || _flingYAnimation.isAnimating;

  bool get _isTouching => _activePointers.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _offset.addListener(_sendScrollInfo);
    _zoomLevel.addListener(_sendScrollInfo);
    _offsetAnimation.addListener(_onAnimateOffsetUpdate);
    _zoomAnimation.addListener(_onAnimateZoomUpdate);
    _scrollRegionChange.addListener(_updateScrollableRegion);
    _viewport.addListener(_onViewportDimensionChanged);
    _childSize.addListener(_onChildSizeChanged);
  }

  @override
  void dispose() {
    _viewportSizeProvider.removeListener(_onViewportChanged);
    _scrollRegionChange..removeListener(_updateScrollableRegion);
    _offset
      ..removeListener(_sendScrollInfo)
      ..dispose();
    _zoomLevel
      ..removeListener(_sendScrollInfo)
      ..dispose();
    _viewport
      ..removeListener(_onViewportDimensionChanged)
      ..dispose();
    _childSize
      ..removeListener(_onChildSizeChanged)
      ..dispose();
    _readyToDisplay..dispose();
    _flingXAnimation..dispose();
    _flingYAnimation..dispose();
    _zoomAnimation
      ..removeListener(_onAnimateZoomUpdate)
      ..dispose();
    _offsetAnimation
      ..removeListener(_onAnimateOffsetUpdate)
      ..dispose();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _viewport.value = _viewportSizeProvider.value;
    _viewportSizeProvider.addListener(_onViewportChanged);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _resetPosition();
    });
  }

  @override
  void didUpdateWidget(covariant MangaPageInteractivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _stopFlinging();
      if (widget.alignment != oldWidget.alignment) {
        _changeAlignmentAxis(oldWidget.alignment, widget.alignment);
      }
      _sendScrollInfo();
    });
  }

  void jumpToOffset(Offset offset) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _stopFlinging();
      _offset.value = _limitOffsetWithinBounds(offset);
    });
  }

  void animateToOffset(Offset offset, [VoidCallback? onEnd]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animateOffsetChange(targetOffset: offset, onEnd: onEnd);
    });
  }

  void _resetPosition() {
    _stopFlinging();
    _updateChildSize();
    _updateScrollableRegion();
    _offset.value = _limitOffsetWithinBounds(_offset.value);
  }

  void _changeAlignmentAxis(
    PanelAlignment oldAlignment,
    PanelAlignment newAlignment,
  ) {
    final childSize = _childSize.value;
    final viewportSize = _viewport.value;

    if (childSize.isEmpty || viewportSize.isEmpty) {
      return;
    }

    double fraction(double value, double min, double max) {
      return (value - min) / (max - min);
    }

    double unfraction(double value, double min, double max) {
      return value * (max - min) + min;
    }

    final currentScrollProgress = switch (oldAlignment) {
      PanelAlignment.left || PanelAlignment.right => fraction(
        _offset.value.dx.abs(),
        _scrollableRegion.left,
        _scrollableRegion.right,
      ),
      PanelAlignment.top || PanelAlignment.bottom => fraction(
        _offset.value.dy.abs(),
        _scrollableRegion.top,
        _scrollableRegion.bottom,
      ),
    }.abs().clamp(0.0, 1.0);

    _updateScrollableRegion();

    Offset newOffset = switch (newAlignment) {
      PanelAlignment.left || PanelAlignment.right => Offset(
        unfraction(
          currentScrollProgress,
          _scrollableRegion.left,
          _scrollableRegion.right,
        ),
        0,
      ),
      PanelAlignment.top || PanelAlignment.bottom => Offset(
        0,
        unfraction(
          currentScrollProgress,
          _scrollableRegion.top,
          _scrollableRegion.bottom,
        ),
      ),
    };
    if (newAlignment == PanelAlignment.bottom ||
        newAlignment == PanelAlignment.right) {
      newOffset = newOffset;
    }

    _offset.value = newOffset;
  }

  void _sendScrollInfo() {
    widget.onScroll?.call(_offset.value, _zoomLevel.value);
  }

  void _onViewportChanged() {
    _viewport.value = _viewportSizeProvider.value;
  }

  void _onViewportDimensionChanged() {
    // This is called when the viewport size changes.
    _updateScrollableAndSettle();
  }

  // Similar to clamp but
  double _limitBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value.clamp(limitA, limitB);
    } else {
      return value.clamp(limitB, limitA);
    }
  }

  void _handleTouch() {
    _stopFlinging();
    _startZoomLevel = _zoomLevel.value;
  }

  void _stopFlinging() {
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

  void _handleZoomDrag(Offset position) {
    final currentZoom = _zoomLevel.value;
    final difference = position.dy - _startTouchPoint!.dy;

    // Compute proposed zoom level
    final zoomSensitivity = 1.005;
    double newZoom = _startZoomLevel! * math.pow(zoomSensitivity, difference);

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

  void _handlePinch(Offset focalPoint, double scale) {
    final currentZoom = _zoomLevel.value;
    double newZoom = _startZoomLevel! * scale;

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
      _startPinchDistance = null;
      _startZoomLevel = null;
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
    _stopFlinging();
    _offset.value = _limitOffsetWithinBounds(newOffset);
  }

  void _updateScrollableRegion() {
    Rect transformZoom(Rect bounds) {
      final padding = (_viewport.value / 2) * (1 - 1 / _zoomLevel.value);

      return Rect.fromLTRB(
        bounds.left - padding.width,
        bounds.top - padding.height,
        bounds.right + padding.width,
        bounds.bottom + padding.height,
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

    // If child is smaller than viewport, center it
    if (left > right) {
      final centerOffset = (left + right) / 2;
      left = right = centerOffset;
    }
    if (top > bottom) {
      final centerOffset = (top + bottom) / 2;
      top = bottom = centerOffset;
    }

    // Inverse coordinate system for inverted directions
    if (widget.alignment == PanelAlignment.right) {
      left = -left;
      right = -right;
    } else if (widget.alignment == PanelAlignment.bottom) {
      top = -top;
      bottom = -bottom;
    }

    final newRegion = Rect.fromLTRB(left, top, right, bottom);

    _scrollableRegion = newRegion;
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
      CurvedAnimation(parent: _offsetAnimation, curve: Curves.easeOut),
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

  void _updateChildSize() {
    final childSize =
        (_childKey.currentContext!.findRenderObject() as RenderBox).size;
    _childSize.value = childSize;
  }

  void _onChildSizeChanged() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScrollableAndSettle();
    });
  }

  void _updateScrollableAndSettle() {
    // Order matters here. The scrollable region must be updated before settling the offset.
    // Otherwise, the offset might be settled based on an outdated scrollable region.
    final oldScrollableRegion = _scrollableRegion;
    _updateScrollableRegion();
    // Only settle if the scrollable region actually changed, to avoid unnecessary animations.
    if (oldScrollableRegion != _scrollableRegion &&
        !_isTouching &&
        !_isFlinging) {
      _settlePageOffset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_readyToDisplay.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _readyToDisplay.value = true;
      });
    }

    return ClipRect(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _activePointers[event.device] = VelocityTracker.withKind(event.kind)
            ..addPosition(event.timeStamp, event.localPosition);
          ;
          _activePositions[event.device] = event.localPosition;

          _handleTouch();

          if (event.device == 0) {
            // Primary touch
            _doubleTapDetector.registerTap(
              event.timeStamp,
              event.localPosition,
            );
            _startTouchPoint = event.localPosition;
          } else if (event.device == 1) {
            // Secondary touch
            _startPinchDistance =
                (_startTouchPoint! - event.localPosition).distance;
          }
          if (event.device == 0 &&
              _doubleTapDetector.isTriggered(event.timeStamp)) {
            _isZoomDragging = true;
          }
        },
        onPointerUp: (event) {
          final tracker = _activePointers[event.device]!;
          _activePointers.remove(event.device);
          _activePositions.remove(event.device);

          if (event.device == 0) {
            _doubleTapDetector.registerUntap(
              event.timeStamp,
              event.localPosition,
            );
          } else if (event.device == 1) {
            // Second touch released
            // Record zoom level in case of user wants to pinch again
            _startZoomLevel = _zoomLevel.value;
          }

          if (_activePointers.isEmpty) {
            if (event.device == 0 &&
                _doubleTapDetector.isTriggered(event.timeStamp)) {
              _handleZoomDoubleTap(_startTouchPoint!);
            } else {
              final magnitude = tracker.getVelocity().pixelsPerSecond.distance;
              if (magnitude > 0 ||
                  !_doubleTapDetector.willTrigger(event.timeStamp)) {
                _handleFling(tracker.getVelocity());
              }
            }
            _handleLift();
          }
        },
        onPointerMove: (event) {
          _activePointers[event.device]!.addPosition(
            event.timeStamp,
            event.localPosition,
          );
          _activePositions[event.device] = event.localPosition;
          _doubleTapDetector.reset();

          if (_isZoomDragging) {
            _handleZoomDrag(event.localPosition);
            return;
          }

          if (_activePointers.containsKey(0) &&
              _activePointers.containsKey(1)) {
            final (firstPoint, secondPoint) = (
              _activePositions[0]!,
              _activePositions[1]!,
            );
            final focalPoint = (firstPoint + secondPoint) / 2;
            final distance = (firstPoint - secondPoint).distance;

            final distanceRatio = _startPinchDistance != null
                ? distance / _startPinchDistance!
                : 1.0;

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
          _handleTouch();
        },
        onPointerPanZoomUpdate: (event) {
          if (event.scale != 1) {
            _handlePinch(event.localPosition, event.scale);
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
              return Transform.translate(offset: -offset, child: child);
            },
            child: ValueListenableBuilder(
              valueListenable: _readyToDisplay,
              builder: (context, readyToDisplay, child) {
                return AnimatedOpacity(
                  opacity: readyToDisplay ? 1 : 0,
                  duration: Duration(milliseconds: 200),
                  child: child,
                );
              },
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: switch (widget.alignment) {
                  PanelAlignment.top => Alignment.topLeft,
                  PanelAlignment.left => Alignment.topLeft,
                  PanelAlignment.bottom => Alignment.bottomLeft,
                  PanelAlignment.right => Alignment.topRight,
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
          ),
        ),
      ),
    );
  }
}
