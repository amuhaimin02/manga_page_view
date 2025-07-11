import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import '../utils.dart';
import 'interactive_panel.dart';
import 'page_carousel.dart';
import 'viewport_size.dart';

/// A builder function for edge gesture indicators.
typedef EdgeDragGestureIndicatorBuilder = Widget Function(
    BuildContext context, MangaPageViewEdgeGestureInfo info);

// Whether the gestures correspond to start or end of the page
enum EdgeDragGestureSide { start, end }

/// Wrapper for detecting page edge gestures typically used for navigating to previous or next chapter
class EdgeDragGestureWrapper extends StatefulWidget {
  const EdgeDragGestureWrapper({
    super.key,
    required this.child,
    required this.direction,
    required this.indicatorSize,
    required this.startEdgeBuilder,
    required this.endEdgeBuilder,
    required this.onStartEdgeDrag,
    required this.onEndEdgeDrag,
  });

  final MangaPageViewDirection direction;
  final Widget child;
  final double indicatorSize;
  final EdgeDragGestureIndicatorBuilder? startEdgeBuilder;
  final EdgeDragGestureIndicatorBuilder? endEdgeBuilder;
  final VoidCallback? onStartEdgeDrag;
  final VoidCallback? onEndEdgeDrag;

  @override
  State<EdgeDragGestureWrapper> createState() => _EdgeDragGestureWrapperState();
}

class _EdgeDragGestureWrapperState extends State<EdgeDragGestureWrapper>
    with SingleTickerProviderStateMixin {
  late final _swipeAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  Animation<double>? _swipeAnimation;

  bool _canMove = false;
  MangaPageViewEdge? _activeEdge;
  EdgeDragGestureSide? _activeSide;
  final _swipeDistance = ValueNotifier(0.0);

  bool _isTriggered = false;

  @override
  void initState() {
    super.initState();
    _swipeAnimationController.addListener(() {
      _swipeDistance.value = _swipeAnimation!.value;
      if (_swipeAnimationController.isCompleted) {
        _onSwipeEnd();
      }
    });
  }

  @override
  void dispose() {
    _swipeAnimationController.dispose();
    super.dispose();
  }

  void _handleSwipe(Offset delta) {
    // Determine which edge user swipes from
    if (_canMove && _activeEdge == null) {
      _handleActivation(delta);
    }

    // Update scrolling distance based on input
    if (_activeEdge != null) {
      switch (_activeEdge!) {
        case MangaPageViewEdge.top:
          _swipeDistance.value += delta.dy;
        case MangaPageViewEdge.bottom:
          _swipeDistance.value -= delta.dy;
        case MangaPageViewEdge.left:
          _swipeDistance.value += delta.dx;
        case MangaPageViewEdge.right:
          _swipeDistance.value -= delta.dx;
      }

      // Check is passing trigger point
      if (!_isTriggered && _swipeDistance.value > widget.indicatorSize) {
        // Check if the edge callback exists. Do not trigger if no callback
        if (_activeSide == EdgeDragGestureSide.start &&
            widget.onStartEdgeDrag == null) {
          return;
        }
        if (_activeSide == EdgeDragGestureSide.end &&
            widget.onEndEdgeDrag == null) {
          return;
        }

        HapticFeedback.heavyImpact();
        setState(() {
          _isTriggered = true;
        });
      } else if (_isTriggered && _swipeDistance.value < widget.indicatorSize) {
        // Undo trigger is user drags back
        setState(() {
          _isTriggered = false;
        });
      }
    }
  }

  void _handleActivation(Offset delta) {
    MangaPageViewEdge? newActiveEdge;
    switch (widget.direction.axis) {
      case Axis.vertical:
        if (delta.dy > 0) {
          newActiveEdge = MangaPageViewEdge.top;
        } else if (delta.dy < 0) {
          newActiveEdge = MangaPageViewEdge.bottom;
        }
        break;
      case Axis.horizontal:
        if (delta.dx > 0) {
          newActiveEdge = MangaPageViewEdge.left;
        } else if (delta.dx < 0) {
          newActiveEdge = MangaPageViewEdge.right;
        }
        break;
    }

    if (newActiveEdge == null) return;

    _activeSide = _determineEdgeSide(widget.direction, newActiveEdge);

    // Do not move if no callback set
    if (_activeSide == EdgeDragGestureSide.start &&
        widget.startEdgeBuilder == null) {
      _canMove = false;
      return;
    }
    if (_activeSide == EdgeDragGestureSide.end &&
        widget.endEdgeBuilder == null) {
      _canMove = false;
      return;
    }

    _activeEdge = newActiveEdge;
  }

  void _handleLift() {
    // Resolve to 0 with easeOut curve
    _swipeAnimation = Tween(begin: _swipeDistance.value, end: 0.0).animate(
      CurvedAnimation(parent: _swipeAnimationController, curve: Curves.easeOut),
    );
    _swipeAnimationController.forward(from: 0);

    if (_isTriggered) {
      switch (widget.direction) {
        case MangaPageViewDirection.down:
          if (_activeEdge == MangaPageViewEdge.top) {
            widget.onStartEdgeDrag?.call();
          } else if (_activeEdge == MangaPageViewEdge.bottom) {
            widget.onEndEdgeDrag?.call();
          }
        case MangaPageViewDirection.up:
          if (_activeEdge == MangaPageViewEdge.top) {
            widget.onEndEdgeDrag?.call();
          } else if (_activeEdge == MangaPageViewEdge.bottom) {
            widget.onStartEdgeDrag?.call();
          }
        case MangaPageViewDirection.right:
          if (_activeEdge == MangaPageViewEdge.left) {
            widget.onStartEdgeDrag?.call();
          } else if (_activeEdge == MangaPageViewEdge.right) {
            widget.onEndEdgeDrag?.call();
          }
        case MangaPageViewDirection.left:
          if (_activeEdge == MangaPageViewEdge.left) {
            widget.onEndEdgeDrag?.call();
          } else if (_activeEdge == MangaPageViewEdge.right) {
            widget.onStartEdgeDrag?.call();
          }
      }
    }
  }

  void _onSwipeEnd() {
    _canMove = false;
    _activeEdge = null;
    _activeSide = null;
    _isTriggered = false;
  }

  // Rose linearly, until reaches point "c" where it then slows steadily. "a" controls effect strength
  double _applyDrag(double drag, double c, double a) {
    if (drag <= c) return drag;
    return c + (drag - c) / (1 + (drag - c) / a);
  }

  EdgeDragGestureSide _determineEdgeSide(
    MangaPageViewDirection direction,
    MangaPageViewEdge edge,
  ) {
    switch ((direction, edge)) {
      case (MangaPageViewDirection.down, MangaPageViewEdge.top):
        return EdgeDragGestureSide.start;
      case (MangaPageViewDirection.down, MangaPageViewEdge.bottom):
        return EdgeDragGestureSide.end;
      case (MangaPageViewDirection.up, MangaPageViewEdge.top):
        return EdgeDragGestureSide.end;
      case (MangaPageViewDirection.up, MangaPageViewEdge.bottom):
        return EdgeDragGestureSide.start;
      case (MangaPageViewDirection.left, MangaPageViewEdge.right):
        return EdgeDragGestureSide.start;
      case (MangaPageViewDirection.left, MangaPageViewEdge.left):
        return EdgeDragGestureSide.end;
      case (MangaPageViewDirection.right, MangaPageViewEdge.right):
        return EdgeDragGestureSide.end;
      case (MangaPageViewDirection.right, MangaPageViewEdge.left):
        return EdgeDragGestureSide.start;
      default:
        throw AssertionError(
          "Invalid edge and direction combination: $direction, $edge",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) {
        if (!GestureUtils.isPrimaryPointer(event)) return;
        _handleSwipe(event.localDelta);
      },
      onPointerUp: (event) {
        if (!GestureUtils.isPrimaryPointer(event)) return;
        _handleLift();
      },
      onPointerCancel: (event) {
        if (!GestureUtils.isPrimaryPointer(event)) return;
        _handleLift();
      },
      onPointerPanZoomUpdate: (event) {
        _handleSwipe(event.localPanDelta);
      },
      onPointerPanZoomEnd: (event) {
        _handleLift();
      },
      child: NotificationListener(
        onNotification: (event) {
          if (event is InteractivePanelReachingEdgeNotification ||
              event is PageCarouselReachingEdgeNotification) {
            // Listen to contents like InteractivePanel, only react when they cannot move further
            _canMove = true;
            return true;
          }
          return false;
        },
        child: ValueListenableBuilder(
          valueListenable: ViewportSize.of(context),
          builder: (context, viewportSize, child) {
            return ValueListenableBuilder(
              valueListenable: _swipeDistance,
              builder: (context, distance, child) {
                final indicatorSize = widget.indicatorSize;

                // Simulate spring effect when overstretch
                final resolvedDistance = _applyDrag(
                  distance,
                  indicatorSize,
                  indicatorSize,
                );
                final edge = _activeEdge;

                // Region for main content
                final childRect = Rect.fromLTWH(
                  switch (edge) {
                    MangaPageViewEdge.left => resolvedDistance,
                    MangaPageViewEdge.right => -resolvedDistance,
                    _ => 0,
                  },
                  switch (edge) {
                    MangaPageViewEdge.top => resolvedDistance,
                    MangaPageViewEdge.bottom => -resolvedDistance,
                    _ => 0,
                  },
                  viewportSize.width,
                  viewportSize.height,
                );

                // Region for indicator content
                final Rect indicatorRect;

                if (edge != null) {
                  indicatorRect = Rect.fromLTWH(
                    switch (edge) {
                      MangaPageViewEdge.left =>
                        resolvedDistance - indicatorSize,
                      MangaPageViewEdge.right =>
                        viewportSize.width - resolvedDistance,
                      _ => 0,
                    },
                    switch (edge) {
                      MangaPageViewEdge.top => resolvedDistance - indicatorSize,
                      MangaPageViewEdge.bottom =>
                        viewportSize.height - resolvedDistance,
                      _ => 0,
                    },
                    edge.isHorizontal ? indicatorSize : viewportSize.width,
                    edge.isVertical ? indicatorSize : viewportSize.height,
                  );
                } else {
                  indicatorRect = Rect.zero;
                }

                Widget? indicatorWidget;

                if (distance > 0 && edge != null) {
                  final info = MangaPageViewEdgeGestureInfo(
                    edge: edge,
                    progress: (distance / indicatorSize).clamp(0, 1),
                    isTriggered: _isTriggered,
                  );

                  final side = _determineEdgeSide(widget.direction, edge);

                  final content = switch (side) {
                    EdgeDragGestureSide.start => widget.startEdgeBuilder!(
                        context,
                        info,
                      ),
                    EdgeDragGestureSide.end => widget.endEdgeBuilder!(
                        context,
                        info,
                      ),
                  };

                  indicatorWidget = Positioned.fromRect(
                    rect: indicatorRect,
                    child: content,
                  );
                }

                return Stack(
                  children: [
                    Positioned.fromRect(rect: childRect, child: widget.child),
                    if (indicatorWidget != null) indicatorWidget,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
