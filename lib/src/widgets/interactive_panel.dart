import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;

import 'double_tap_detector.dart';
import 'viewport_size.dart';

const _trackpadDeviceId = 99;
const _defaultZoomAnimationDuration = Duration(milliseconds: 300);
const _defaultZoomAnimationCurve = Curves.easeInOut;

enum InteractivePanelAlignment { top, bottom, left, right }

class InteractivePanelCannotPanNotification extends Notification {}

class InteractivePanel extends StatefulWidget {
  const InteractivePanel({
    super.key,
    required this.child,
    required this.initialZoomLevel,
    required this.initialFadeInDuration,
    required this.initialFadeInCurve,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.presetZoomLevels,
    required this.verticalOverscroll,
    required this.horizontalOverscroll,
    required this.alignment,
    required this.zoomOnFocalPoint,
    required this.zoomOvershoot,
    required this.panCheckAxis,
    this.onScroll,
  });

  final Widget child;
  final double initialZoomLevel;
  final Duration initialFadeInDuration;
  final Curve initialFadeInCurve;
  final double minZoomLevel;
  final double maxZoomLevel;
  final List<double> presetZoomLevels;
  final bool verticalOverscroll;
  final bool horizontalOverscroll;
  final InteractivePanelAlignment alignment;
  final bool zoomOnFocalPoint;
  final bool zoomOvershoot;
  final Axis? panCheckAxis;
  final Function(Offset offset, double zoomLevel)? onScroll;

  @override
  State<InteractivePanel> createState() => InteractivePanelState();
}

class InteractivePanelState extends State<InteractivePanel>
    with TickerProviderStateMixin {
  late final _childKey = GlobalKey();

  late final _flingXAnimation = AnimationController.unbounded(vsync: this);
  late final _flingYAnimation = AnimationController.unbounded(vsync: this);
  late final _offsetAnimation = AnimationController(vsync: this);
  late final _zoomAnimation = AnimationController(vsync: this);
  late final _firstAppearanceAnimation = AnimationController(
    vsync: this,
    duration: widget.initialFadeInDuration,
  );

  VoidCallback? _offsetAnimationUpdateListener;
  VoidCallback? _zoomAnimationUpdateListener;

  final _activePointers = <int, VelocityTracker>{};
  final _activePositions = <int, Offset>{};
  final _doubleTapDetector = DoubleTapDetector();
  Offset? _startTouchPoint;
  double? _startPinchDistance;
  double? _startZoomLevel;

  late final _offset = ValueNotifier(Offset.zero);
  late final _zoomLevel = ValueNotifier(widget.initialZoomLevel);

  Offset get offset => _offset.value;
  double get zoomLevel => _zoomLevel.value;

  late final _childSize = ValueNotifier(Size.zero);
  late final _viewport = ValueNotifier(Size.zero);
  late final _viewportSizeProvider = ViewportSize.of(context);

  late final _scrollRegionChange = Listenable.merge([_zoomLevel, _viewport]);

  Rect _scrollableRegion = Rect.zero;

  Rect get scrollableRegion => _scrollableRegion;

  bool get _isFlinging =>
      _flingXAnimation.isAnimating || _flingYAnimation.isAnimating;
  bool get _isTouching => _activePointers.isNotEmpty;
  bool _isPinching = false;
  bool _isPanning = false;
  bool _isPanLocked = false;
  bool _isZoomDragging = false;

  @override
  void initState() {
    super.initState();
    _offset.addListener(_sendScrollInfo);
    _zoomLevel.addListener(_sendScrollInfo);
    _offsetAnimation.addListener(_onAnimateOffsetUpdate);
    _zoomAnimation.addListener(_onAnimateZoomUpdate);
    _scrollRegionChange.addListener(_updateScrollableRegion);
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
    _viewport..dispose();
    _childSize
      ..removeListener(_onChildSizeChanged)
      ..dispose();
    _flingXAnimation..dispose();
    _flingYAnimation..dispose();
    _zoomAnimation
      ..removeListener(_onAnimateZoomUpdate)
      ..dispose();
    _offsetAnimation
      ..removeListener(_onAnimateOffsetUpdate)
      ..dispose();
    _firstAppearanceAnimation..dispose();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _firstAppearanceAnimation.forward(from: 0);
    _viewport.value = _viewportSizeProvider.value;

    _viewportSizeProvider.addListener(_onViewportChanged);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _resetPosition();
      _sendScrollInfo();
    });
  }

  @override
  void didUpdateWidget(covariant InteractivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _firstAppearanceAnimation.forward(from: 0);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _stopFlinging();
      if (widget.alignment != oldWidget.alignment) {
        _changeAlignmentAxis(oldWidget.alignment, widget.alignment);
      }
      _sendScrollInfo();
    });
  }

  void _onViewportChanged() {
    _viewport.value = _viewportSizeProvider.value;
    _updateScrollableRegion();
    _offset.value = _limitOffsetInScrollable(_offset.value);
  }

  void jumpToOffset(Offset offset) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _stopFlinging();
      _offset.value = _limitOffsetInScrollable(offset);
    });
  }

  void animateToOffset(
    Offset offset,
    Duration duration,
    Curve curve, {
    VoidCallback? onEnd,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animateOffsetChange(offset, duration, curve, onEnd: onEnd);
    });
  }

  void zoomTo(double zoomLevel) {
    _zoomLevel.value = zoomLevel.clamp(
      widget.minZoomLevel,
      widget.maxZoomLevel,
    );
    _settlePageOffset();
  }

  void animateZoomTo(double zoomLevel, Duration duration, Curve curve) {
    _animateZoomChange(zoomLevel, duration, curve);
  }

  void _resetPosition() {
    _stopFlinging();
    _updateChildSize();
    _updateScrollableRegion();
    _offset.value = _limitOffsetInScrollable(_offset.value);
  }

  void _changeAlignmentAxis(
    InteractivePanelAlignment oldAlignment,
    InteractivePanelAlignment newAlignment,
  ) {
    final childSize = _childSize.value;
    final viewportSize = _viewport.value;

    if (childSize.isEmpty || viewportSize.isEmpty) return;

    double fraction(double value, double min, double max) {
      return (value - min) / (max - min);
    }

    double unfraction(double value, double min, double max) {
      return value * (max - min) + min;
    }

    final currentScrollProgress = switch (oldAlignment) {
      InteractivePanelAlignment.left ||
      InteractivePanelAlignment.right => fraction(
        _offset.value.dx.abs(),
        _scrollableRegion.left,
        _scrollableRegion.right,
      ),
      InteractivePanelAlignment.top ||
      InteractivePanelAlignment.bottom => fraction(
        _offset.value.dy.abs(),
        _scrollableRegion.top,
        _scrollableRegion.bottom,
      ),
    }.abs().clamp(0.0, 1.0);

    _updateScrollableRegion();

    Offset newOffset = switch (newAlignment) {
      InteractivePanelAlignment.left ||
      InteractivePanelAlignment.right => Offset(
        unfraction(
          currentScrollProgress,
          _scrollableRegion.left,
          _scrollableRegion.right,
        ),
        0,
      ),
      InteractivePanelAlignment.top ||
      InteractivePanelAlignment.bottom => Offset(
        0,
        unfraction(
          currentScrollProgress,
          _scrollableRegion.top,
          _scrollableRegion.bottom,
        ),
      ),
    };
    if (newAlignment == InteractivePanelAlignment.bottom ||
        newAlignment == InteractivePanelAlignment.right) {
      newOffset = newOffset;
    }

    _offset.value = _limitOffsetInScrollable(newOffset);
  }

  void _sendScrollInfo() {
    widget.onScroll?.call(_offset.value, _zoomLevel.value);
  }

  // Similar to clamp but min and max can be either way (A or B used instead)
  double _limitBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value.clamp(limitA, limitB);
    } else {
      return value.clamp(limitB, limitA);
    }
  }

  bool _isInBound(double value, double limitA, double limitB) {
    if (limitA <= limitB) {
      return value > limitA && value < limitB;
    } else {
      return value > limitB && value < limitA;
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
    if (_isPanLocked) return;

    final deltaX = delta.dx / _zoomLevel.value;
    final deltaY = delta.dy / _zoomLevel.value;

    var newX = _offset.value.dx - deltaX;
    var newY = _offset.value.dy - deltaY;

    if (!widget.horizontalOverscroll) {
      newX = _limitBound(newX, _scrollableRegion.left, _scrollableRegion.right);
    }

    if (!widget.verticalOverscroll) {
      newY = _limitBound(newY, _scrollableRegion.top, _scrollableRegion.bottom);
    }

    final newOffset = Offset(newX, newY);

    if (!_isPanning) {
      // First time panning
      _isPanning = true;

      _checkPanPossible(newOffset);
    } else {
      _offset.value = newOffset;
    }
  }

  void _checkPanPossible(Offset offset) {
    if (_isPinching) return;

    bool cannotPan = false;
    final axis = widget.panCheckAxis;

    if (axis != null) {
      // Check if user is trying to pan out of bounds
      if (axis == Axis.horizontal) {
        if (!_isInBound(
          offset.dx,
          _scrollableRegion.left,
          _scrollableRegion.right,
        )) {
          cannotPan = true;
        }
      } else if (axis == Axis.vertical) {
        if (!_isInBound(
          offset.dy,
          _scrollableRegion.top,
          _scrollableRegion.bottom,
        )) {
          cannotPan = true;
        }
      }

      // If user is trying to pan out of bounds, lock panning and notify

      if (cannotPan) {
        InteractivePanelCannotPanNotification().dispatch(context);
        _isPanLocked = true;
      }
    }
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

    return _limitOffsetInScrollable(_offset.value + moveOffset / finalZoom);
  }

  void _handleZoomDrag(Offset position) {
    if (_isPanLocked) return;

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
      _offset.value = _limitOffsetInScrollable(_offset.value);
    }
  }

  void _handleFling(Velocity velocity) {
    if (_isPanLocked) return;

    _settlePageOffset(velocity: velocity.pixelsPerSecond / _zoomLevel.value);
    _settleZoom();
  }

  void _handlePinch(Offset focalPoint, double scale) {
    if (_isPanLocked) return;

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
      _offset.value = _limitOffsetInScrollable(_offset.value);
    }
  }

  void _handleLift() {
    if (_activePointers.isEmpty) {
      _isZoomDragging = false;
      _isPanning = false;
      _isPinching = false;
      _isPanLocked = false;
      _startTouchPoint = null;
      _startPinchDistance = null;
      _startZoomLevel = null;
    }
  }

  void _handleZoomDoubleTap(Offset touchPoint) {
    final presetZoomLevels = [...widget.presetZoomLevels]..sort();

    if (presetZoomLevels.isEmpty) {
      // Default behavior if no preset levels are defined
      _animateZoomChange(
        1.0,
        _defaultZoomAnimationDuration,
        _defaultZoomAnimationCurve,
        focalPoint: touchPoint,
      );
      return;
    }

    double nextZoomLevel = presetZoomLevels.firstWhere(
      (level) => level > _zoomLevel.value,
      orElse: () => presetZoomLevels.first,
    );

    _animateZoomChange(
      nextZoomLevel,
      _defaultZoomAnimationDuration,
      _defaultZoomAnimationCurve,
      focalPoint: touchPoint,
    );
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
        _offset.value = _limitOffsetInScrollable(_offset.value);
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
    _offset.value = _limitOffsetInScrollable(newOffset);
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
    if (widget.alignment == InteractivePanelAlignment.right) {
      left = -left;
      right = -right;
    } else if (widget.alignment == InteractivePanelAlignment.bottom) {
      top = -top;
      bottom = -bottom;
    }

    final newRegion = Rect.fromLTRB(left, top, right, bottom);

    _scrollableRegion = newRegion;
  }

  Offset _limitOffsetInScrollable(Offset offset) {
    return Offset(
      _limitBound(offset.dx, _scrollableRegion.left, _scrollableRegion.right),
      _limitBound(offset.dy, _scrollableRegion.top, _scrollableRegion.bottom),
    );
  }

  void _settleZoom() {
    final settledZoomLevel = _zoomLevel.value.clamp(
      widget.minZoomLevel,
      widget.maxZoomLevel,
    );
    _animateZoomChange(
      settledZoomLevel,
      _defaultZoomAnimationDuration,
      _defaultZoomAnimationCurve,
      handleOffset: false,
    );
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

  void _animateZoomChange(
    double targetLevel,
    Duration duration,
    Curve curve, {
    bool handleOffset = true,
    Offset? focalPoint = null,
  }) {
    final currentLevel = _zoomLevel.value;
    final zoomTween = Tween<double>(
      begin: currentLevel,
      end: targetLevel,
    ).animate(CurvedAnimation(parent: _zoomAnimation, curve: curve));

    _zoomAnimationUpdateListener = () {
      final currentZoom = _zoomLevel.value;
      final newZoom = zoomTween.value;
      _zoomLevel.value = newZoom;
      if (handleOffset) {
        if (focalPoint != null && widget.zoomOnFocalPoint) {
          _offset.value = _calculateOffsetAfterZoom(
            focalPoint,
            currentZoom,
            newZoom,
          );
        } else {
          _offset.value = _limitOffsetInScrollable(_offset.value);
        }
        if (_zoomAnimation.isCompleted) {
          _settlePageOffset();
        }
      }
    };

    _zoomAnimation
      ..duration = duration
      ..forward(from: 0);
  }

  void _animateOffsetChange(
    Offset targetOffset,
    Duration duration,
    Curve curve, {
    VoidCallback? onEnd,
  }) {
    final currentOffset = _offset.value;

    final offsetTween = Tween<Offset>(
      begin: currentOffset,
      end: _limitOffsetInScrollable(targetOffset),
    ).animate(CurvedAnimation(parent: _offsetAnimation, curve: curve));

    _offsetAnimationUpdateListener = () {
      _offset.value = offsetTween.value;
      if (_offsetAnimation.isCompleted) {
        _settlePageOffset();
        onEnd?.call();
      }
    };

    _offsetAnimation
      ..duration = duration
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
    return ClipRect(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          // Only detects left mouse click or touch
          if (event.buttons & kPrimaryButton == 0) return;

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

            if (_doubleTapDetector.isActive(event.timeStamp)) {
              _isZoomDragging = true;
            }
          } else if (event.device == 1) {
            // Secondary touch
            final firstTouchPosition = _activePositions[0];
            final secondTouchPosition = _activePositions[1];
            if (firstTouchPosition != null && secondTouchPosition != null) {
              _startPinchDistance =
                  (firstTouchPosition - secondTouchPosition).distance;
            }
          }
        },
        onPointerUp: (event) {
          // Skip if the gestures aren't captured by pointerDown/pointerMove events
          if (!_activePointers.containsKey(event.device)) return;

          final tracker = _activePointers[event.device]!;
          _activePointers.remove(event.device);
          _activePositions.remove(event.device);

          if (event.device == 1) {
            // Second touch released
            // Record zoom level in case of user wants to pinch again
            _isPinching = false;
            _startZoomLevel = _zoomLevel.value;
          }

          if (_activePointers.isEmpty) {
            if (_doubleTapDetector.isActive(event.timeStamp)) {
              _handleZoomDoubleTap(event.localPosition);
            } else {
              final magnitude = tracker.getVelocity().pixelsPerSecond.distance;
              if (magnitude > 300 ||
                  !_doubleTapDetector.isAwaitingSecondTap(
                    event.timeStamp,
                    event.localPosition,
                  )) {
                _handleFling(tracker.getVelocity());
              }
            }
            _handleLift();
          }
        },
        onPointerMove: (event) {
          // Only detects left mouse click or touch
          if (event.buttons & kPrimaryButton == 0) return;

          // Skip if pointer is not really moving
          // Often triggers on devices with high sampling rate
          if (event.localDelta == Offset.zero) return;

          _activePointers[event.device]!.addPosition(
            event.timeStamp,
            event.localPosition,
          );
          _activePositions[event.device] = event.localPosition;

          if (_isZoomDragging) {
            _handleZoomDrag(event.localPosition);
            return;
          }

          if (_activePointers.containsKey(0) &&
              _activePointers.containsKey(1)) {
            _isPinching = true;

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
            _isPinching = true;
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
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _firstAppearanceAnimation,
                curve: widget.initialFadeInCurve,
              ),
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: switch (widget.alignment) {
                  InteractivePanelAlignment.top => Alignment.topLeft,
                  InteractivePanelAlignment.left => Alignment.topLeft,
                  InteractivePanelAlignment.bottom => Alignment.bottomLeft,
                  InteractivePanelAlignment.right => Alignment.topRight,
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
