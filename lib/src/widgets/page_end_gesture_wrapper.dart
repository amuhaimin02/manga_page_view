import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:manga_page_view/src/widgets/interactive_panel.dart';
import 'package:manga_page_view/src/widgets/page_carousel.dart';

import 'viewport_size.dart';

typedef PageEndGestureIndicatorBuilder =
    Widget Function(
      BuildContext context,
      MangaPageViewEdge edge,
      double progress,
      bool triggered,
    );

class PageEndGestureWrapper extends StatefulWidget {
  const PageEndGestureWrapper({
    super.key,
    required this.child,
    required this.detectionAxis,
    required this.indicatorSize,
    required this.indicatorBuilder,
  });

  final Axis detectionAxis;
  final Widget child;
  final double indicatorSize;
  final PageEndGestureIndicatorBuilder? indicatorBuilder;

  @override
  State<PageEndGestureWrapper> createState() => _PageEndGestureWrapperState();
}

class _PageEndGestureWrapperState extends State<PageEndGestureWrapper>
    with SingleTickerProviderStateMixin {
  late final _swipeAnimationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 250),
  );

  Animation<double>? _swipeAnimation;

  bool _canMove = false;
  MangaPageViewEdge? _activeEdge;
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

  void _handleTouch() {}

  void _handleSwipe(Offset delta) {
    // Determine which edge user swipes from
    if (_canMove && _activeEdge == null) {
      if (widget.detectionAxis == Axis.vertical) {
        if (delta.dy > 0) {
          _activeEdge = MangaPageViewEdge.top;
        } else if (delta.dy < 0) {
          _activeEdge = MangaPageViewEdge.bottom;
        }
      } else if (widget.detectionAxis == Axis.horizontal) {
        if (delta.dx > 0) {
          _activeEdge = MangaPageViewEdge.left;
        } else if (delta.dx < 0) {
          _activeEdge = MangaPageViewEdge.right;
        }
      }
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
        HapticFeedback.heavyImpact();
        setState(() {
          _isTriggered = true;
        });
      } else if (_isTriggered && _swipeDistance.value < widget.indicatorSize) {
        setState(() {
          _isTriggered = false;
        });
      }
    }
  }

  void _handleLift() {
    // Resolve to 0 with easeOut curve
    _swipeAnimation = Tween(begin: _swipeDistance.value, end: 0.0).animate(
      CurvedAnimation(parent: _swipeAnimationController, curve: Curves.easeOut),
    );
    _swipeAnimationController.forward(from: 0);
  }

  void _onSwipeEnd() {
    _canMove = false;
    _activeEdge = null;
    _isTriggered = false;
  }

  // Rose linearly, until reaches point "c" where it then slows steadily. "a" controls effect strength
  double _applyDrag(double drag, double c, double a) {
    if (drag <= c) return drag;
    return c + (drag - c) / (1 + (drag - c) / a);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.device != 0) return;
        _handleTouch();
      },
      onPointerMove: (event) {
        if (event.device != 0) return;
        _handleSwipe(event.localDelta);
      },
      onPointerUp: (event) {
        if (event.device != 0) return;
        _handleLift();
      },
      onPointerCancel: (event) {
        if (event.device != 0) return;
        _handleLift();
      },
      onPointerPanZoomStart: (event) {
        _handleTouch();
      },
      onPointerPanZoomUpdate: (event) {
        _handleSwipe(event.localDelta);
      },
      onPointerPanZoomEnd: (event) {
        _handleLift();
      },
      child: NotificationListener(
        onNotification: (event) {
          if (event is InteractivePanelReachingEdgeNotification ||
              event is PageCarouselReachingEdgeNotification) {
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

                final resolvedDistance = _applyDrag(
                  distance,
                  indicatorSize,
                  indicatorSize,
                );
                final edge = _activeEdge;

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

                return Stack(
                  children: [
                    Positioned.fromRect(rect: childRect, child: widget.child),
                    if (distance > 0 && edge != null)
                      Positioned.fromRect(
                        rect: indicatorRect,
                        child: widget.indicatorBuilder!(
                          context,
                          edge,
                          (distance / indicatorSize).clamp(0, 1),
                          _isTriggered,
                        ),
                      ),
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
