import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import 'interactive_panel.dart';
import 'viewport.dart';

const flingVelocityThreshold = 500;

class MangaPagePagedView extends StatefulWidget {
  const MangaPagePagedView({
    super.key,
    required this.options,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.initialPageIndex,
    this.onPageChange,
    this.onProgressChange,
    this.onZoomChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int initialPageIndex;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(double progress)? onProgressChange;
  final Function(double zoomLevel)? onZoomChange;

  @override
  State<MangaPagePagedView> createState() => _MangaPagePagedViewState();
}

class _MangaPagePagedViewState extends State<MangaPagePagedView> {
  late final _carouselKey = GlobalKey<_PageCarouselState>();
  final Map<int, GlobalKey<InteractivePanelState>> _panelKeys = {};

  _PageCarouselState get _carouselState => _carouselKey.currentState!;
  InteractivePanelState? get _activePanelState =>
      _panelKeys[_currentPage]?.currentState;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

  late int _currentPage = widget.initialPageIndex;
  late double _currentProgress = _pageIndexToProgress(_currentPage);

  StreamSubscription<ControllerChangeIntent>? _controllerIntentStream;

  @override
  void initState() {
    super.initState();
    _controllerIntentStream = widget.controller.intents.listen(
      _onControllerIntent,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controllerIntentStream?.cancel();
  }

  void _onControllerIntent(ControllerChangeIntent intent) {
    switch (intent) {
      case PageChangeIntent(:final index, :final duration, :final curve):
        if (duration > Duration.zero) {
          _carouselState.animateToPage(index, duration, curve);
        } else {
          _carouselState.jumpToPage(index);
        }
      case ZoomChangeIntent(:final zoomLevel, :final duration, :final curve):
        if (duration > Duration.zero) {
          _activePanelState!.zoomTo(zoomLevel);
        } else {
          _activePanelState!.animateZoomTo(zoomLevel, duration, curve);
        }
      case ProgressChangeIntent(:final progress, :final duration, :final curve):
        _currentProgress = progress;
        widget.onProgressChange?.call(_currentProgress);
        final targetIndex = _progressToPageIndex(progress);
        if (targetIndex != _currentPage) {
          if (duration > Duration.zero) {
            _carouselState.animateToPage(targetIndex, duration, curve);
          } else {
            _carouselState.jumpToPage(targetIndex);
          }
        }
    }
  }

  double _pageIndexToProgress(int pageIndex) {
    return (pageIndex / (widget.pageCount - 1)).clamp(0, 1);
  }

  int _progressToPageIndex(double progress) {
    return (progress * (widget.pageCount - 1)).round().clamp(
      0,
      widget.pageCount - 1,
    );
  }

  void _onPageChange(int index) {
    _currentPage = index;

    widget.onPageChange?.call(index);

    widget.onProgressChange?.call(_pageIndexToProgress(index));

    if (_activePanelState != null) {
      widget.onZoomChange?.call(
        _activePanelState!.zoomLevel.clamp(
          widget.options.minZoomLevel,
          widget.options.maxZoomLevel,
        ),
      );
    }
  }

  void _onPanelScroll(int pageIndex, Offset offset, double zoomLevel) {
    if (pageIndex == _currentPage) {
      widget.onZoomChange?.call(
        zoomLevel.clamp(
          widget.options.minZoomLevel,
          widget.options.maxZoomLevel,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageCarousel(
      key: _carouselKey,
      initialIndex: widget.initialPageIndex,
      direction: widget.options.direction,
      itemCount: widget.pageCount,
      onPageChange: _onPageChange,
      itemBuilder: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, int index) {
    // Create keys for panel if not exists. We need them to manipulate the panel states later on.
    final panelKey = _panelKeys.putIfAbsent(
      index,
      () => GlobalKey<InteractivePanelState>(),
    );
    return InteractivePanel(
      key: panelKey,
      initialZoomLevel: widget.options.initialZoomLevel,
      minZoomLevel: 1,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels
          .where((z) => z >= 1)
          .toList(),
      verticalOverscroll:
          widget.options.direction.isHorizontal &&
          widget.options.crossAxisOverscroll,
      horizontalOverscroll:
          widget.options.direction.isVertical &&
          widget.options.crossAxisOverscroll,
      alignment: switch (widget.options.direction) {
        PageViewDirection.down => InteractivePanelAlignment.top,
        PageViewDirection.right => InteractivePanelAlignment.left,
        PageViewDirection.up => InteractivePanelAlignment.bottom,
        PageViewDirection.left => InteractivePanelAlignment.right,
      },
      zoomOnFocalPoint: widget.options.zoomOnFocalPoint,
      zoomOvershoot: widget.options.zoomOvershoot,
      panCheckAxis: widget.options.direction.axis,
      onScroll: (offset, zoomLevel) => _onPanelScroll(index, offset, zoomLevel),
      child: _buildPage(context, index),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return ValueListenableBuilder(
      valueListenable: ViewportSizeProvider.of(context),
      builder: (context, value, child) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _viewportSize.width,
            maxHeight: _viewportSize.height,
          ),
          child: FittedBox(fit: BoxFit.contain, child: child),
        );
      },
      child: widget.pageBuilder(context, index),
    );
  }
}

class _PageCarousel extends StatefulWidget {
  const _PageCarousel({
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
  final PageViewDirection direction;
  final Function(int index)? onPageChange;

  @override
  State<_PageCarousel> createState() => _PageCarouselState();
}

class _PageCarouselState extends State<_PageCarousel>
    with SingleTickerProviderStateMixin {
  late Map<int, Widget> _loadedWidgets = {};

  late final _scrollProgress = ValueNotifier(0.0);
  late final AnimationController _snapAnimation;
  VoidCallback? _snapAnimationUpdateListener;

  late int _currentIndex = widget.initialIndex;
  bool _canMove = false;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;
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
  void didUpdateWidget(covariant _PageCarousel oldWidget) {
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
    final double deltaValue;
    final double fullScrollSize;
    if (widget.direction.isHorizontal) {
      deltaValue = delta.dx;
      fullScrollSize = _viewportSize.width;
    } else {
      deltaValue = delta.dy;
      fullScrollSize = _viewportSize.height;
    }

    final progress = _scrollProgress.value - (deltaValue / fullScrollSize);
    _scrollProgress.value = progress.clamp(-1.0, 1.0);
  }

  void _snapToNearest(Velocity flingVelocity) {
    if (!_canMove) {
      return;
    }
    _canMove = false;

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
          if (event is InteractivePanelCannotPanNotification) {
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

            return Stack(
              children: [
                for (final item in _loadedWidgets.entries)
                  Transform.translate(
                    key: ValueKey(item.key),
                    offset: Offset(
                      widget.direction.isHorizontal
                          ? (item.key - _currentIndex - progress) * scrollSize
                          : 0,
                      widget.direction.isVertical
                          ? (item.key - _currentIndex - progress) * scrollSize
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
