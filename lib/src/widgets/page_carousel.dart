import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';

import 'interactive_panel.dart';
import 'viewport_size.dart';

const flingVelocityThreshold = 500;

class PageCarouselReachingEdgeNotification extends Notification {
  const PageCarouselReachingEdgeNotification();
}

class PageCarousel extends StatefulWidget {
  const PageCarousel({
    super.key,
    this.initialIndex = 0,
    required this.itemCount,
    required this.itemBuilder,
    required this.direction,
    required this.onPageChange,
  });

  final int initialIndex;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final MangaPageViewDirection direction;
  final Function(int index)? onPageChange;

  @override
  State<PageCarousel> createState() => PageCarouselState();
}

class PageCarouselState extends State<PageCarousel>
    with SingleTickerProviderStateMixin {
  late Map<int, Widget> _loadedWidgets = {};

  late final _scrollProgress = ValueNotifier(0.0);
  late final AnimationController _snapAnimation;
  VoidCallback? _snapAnimationUpdateListener;

  late int _currentIndex = widget.initialIndex;
  bool _canMove = false;
  bool _panLocked = false;

  Size get _viewportSize => ViewportSize.of(context).value;
  VelocityTracker? _velocityTracker;

  @override
  void initState() {
    super.initState();
    _snapAnimation = AnimationController(vsync: this);
    _snapAnimation.addListener(_onSnapAnimationUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePageContents();
  }

  @override
  void didUpdateWidget(covariant PageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.direction != oldWidget.direction) {
      _loadedWidgets = {};
    }
    _updatePageContents();
  }

  @override
  void dispose() {
    super.dispose();
    _snapAnimation.removeListener(_onSnapAnimationUpdate);
    _snapAnimation.dispose();
    _scrollProgress.dispose();
  }

  void jumpToPage(int newIndex) {
    _currentIndex = newIndex;
    widget.onPageChange?.call(newIndex);
    _updatePageContents();
  }

  void animateToPage(int newIndex, Duration duration, Curve curve) {
    if (newIndex == _currentIndex ||
        newIndex < 0 ||
        newIndex >= widget.itemCount) {
      return;
    }

    // Early callback
    widget.onPageChange?.call(newIndex);

    final difference = newIndex - _currentIndex;

    final snapTween = Tween<double>(
      begin: _scrollProgress.value,
      end: difference.toDouble(),
    ).animate(CurvedAnimation(parent: _snapAnimation, curve: curve));

    _snapAnimationUpdateListener = () {
      _scrollProgress.value = snapTween.value;
      if (_snapAnimation.isCompleted) {
        _afterSnap();
      }
    };

    _snapAnimation
      ..duration = duration
      ..forward(from: 0);
  }

  void _onSnapAnimationUpdate() {
    _snapAnimationUpdateListener?.call();
  }

  void _updatePageContents() {
    Map<int, Widget> _newLoadedWidgets = {};

    _newLoadedWidgets[_currentIndex] =
        _loadedWidgets[_currentIndex] ??
        widget.itemBuilder(context, _currentIndex);

    for (int i = 1; i <= 3; i++) {
      final previousIndex = _currentIndex - i;
      if (previousIndex >= 0) {
        _newLoadedWidgets[previousIndex] =
            _loadedWidgets[previousIndex] ??
            widget.itemBuilder(context, previousIndex);
      }
      final nextIndex = _currentIndex + i;
      if (nextIndex < widget.itemCount) {
        _newLoadedWidgets[nextIndex] =
            _loadedWidgets[nextIndex] ?? widget.itemBuilder(context, nextIndex);
      }
    }
    setState(() {
      _loadedWidgets = _newLoadedWidgets;
    });
  }

  void _updatePan(Offset delta) {
    if (_panLocked) return;

    final double deltaValue;
    final double fullScrollSize;
    if (widget.direction.isHorizontal) {
      deltaValue = delta.dx;
      fullScrollSize = _viewportSize.width;
    } else {
      deltaValue = delta.dy;
      fullScrollSize = _viewportSize.height;
    }
    final reverseFactor = widget.direction.isReverse ? -1 : 1;

    double progress =
        _scrollProgress.value - (deltaValue / fullScrollSize) * reverseFactor;

    // Check if on edge
    if (_currentIndex == 0 && progress < 0 ||
        _currentIndex == widget.itemCount - 1 && progress > 0) {
      PageCarouselReachingEdgeNotification().dispatch(context);
      _panLocked = true;
      progress = 0;
    }

    _scrollProgress.value = progress.clamp(-1.0, 1.0);
  }

  void _snapToNearest(Velocity flingVelocity) {
    _canMove = false;
    _panLocked = false;

    final double velocityValue = widget.direction.isHorizontal
        ? flingVelocity.pixelsPerSecond.dx
        : flingVelocity.pixelsPerSecond.dy;

    final scrollProgress = _scrollProgress.value;

    final moreThanHalf = scrollProgress.abs() > 0.5;
    final isFlinging = velocityValue.abs() > flingVelocityThreshold;
    final newIndex =
        _currentIndex + scrollProgress.sign * (scrollProgress.truncate() + 1);

    final shouldSnap =
        (moreThanHalf || isFlinging) &&
        (newIndex >= 0 && newIndex < widget.itemCount);

    final target = shouldSnap ? scrollProgress.sign : 0.0;

    final snapTween = Tween<double>(
      begin: scrollProgress,
      end: target,
    ).animate(CurvedAnimation(parent: _snapAnimation, curve: Curves.easeOut));

    _snapAnimationUpdateListener = () {
      _scrollProgress.value = snapTween.value;
      if (_snapAnimation.isCompleted) _afterSnap();
    };

    _snapAnimation
      ..duration = const Duration(milliseconds: 200)
      ..forward(from: 0);
  }

  void _afterSnap() {
    final progress = _scrollProgress.value;

    _currentIndex = _currentIndex + progress.toInt();
    _updatePageContents();

    _currentIndex = _currentIndex.clamp(0, widget.itemCount - 1);
    widget.onPageChange?.call(_currentIndex);
    _scrollProgress.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.device == 0) {
          // Primary touch
          _velocityTracker = VelocityTracker.withKind(event.kind);
        }
      },
      onPointerMove: (event) {
        if (!_canMove) {
          return;
        }

        if (event.device == 0) {
          // Primary touch
          _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
          _updatePan(event.localDelta);
        }
      },
      onPointerUp: (event) {
        if (event.device == 0) {
          _snapToNearest(_velocityTracker!.getVelocity());
        }
      },
      onPointerCancel: (event) {
        _snapToNearest(Velocity.zero);
      },
      // Trackpad
      onPointerPanZoomStart: (event) {
        _velocityTracker = VelocityTracker.withKind(event.kind);
      },
      onPointerPanZoomUpdate: (event) {
        _velocityTracker?.addPosition(event.timeStamp, event.pan);
        _updatePan(event.panDelta);
      },
      onPointerPanZoomEnd: (event) {
        _snapToNearest(_velocityTracker!.getVelocity());
      },
      child: NotificationListener(
        onNotification: (event) {
          if (event is InteractivePanelReachingEdgeNotification) {
            _canMove = true;
            return true;
          }
          return false;
        },
        child: ValueListenableBuilder(
          valueListenable: _scrollProgress,
          builder: (context, progress, child) {
            final double scrollSize;

            if (widget.direction.isHorizontal) {
              scrollSize = _viewportSize.width;
            } else {
              scrollSize = _viewportSize.height;
            }
            final reverseFactor = widget.direction.isReverse ? -1 : 1;

            return Stack(
              children: [
                for (final item in _loadedWidgets.entries)
                  Transform.translate(
                    key: ValueKey(item.key),
                    offset: Offset(
                      widget.direction.isHorizontal
                          ? (item.key - _currentIndex - progress) *
                                scrollSize *
                                reverseFactor
                          : 0,
                      widget.direction.isVertical
                          ? (item.key - _currentIndex - progress) *
                                scrollSize *
                                reverseFactor
                          : 0,
                    ),
                    child: item.value,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
