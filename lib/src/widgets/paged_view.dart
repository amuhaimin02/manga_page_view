import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import 'interactive_panel.dart';
import 'viewport.dart';

class MangaPagePagedView extends StatefulWidget {
  const MangaPagePagedView({
    super.key,
    required this.options,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.initialPageIndex,
    this.onPageChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int initialPageIndex;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;

  @override
  State<MangaPagePagedView> createState() => _MangaPagePagedViewState();
}

class _MangaPagePagedViewState extends State<MangaPagePagedView> {
  late final _carouselKey = GlobalKey<_PageCarouselState>();

  _PageCarouselState get _carouselState => _carouselKey.currentState!;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

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
      case PageChangeIntent(index: final pageIndex, animate: final animate):
        if (animate) {
          _carouselState.animateToPage(pageIndex);
        } else {
          _carouselState.jumpToPage(pageIndex);
        }
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageCarousel(
      key: _carouselKey,
      initialIndex: widget.initialPageIndex,
      direction: widget.options.direction,
      itemCount: widget.pageCount,
      onPageChange: widget.onPageChange,
      itemBuilder: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, int index) {
    return InteractivePanel(
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

  double? _touchPoint = null;
  late int _currentIndex = widget.initialIndex;
  bool _canMove = false;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

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

  void animateToPage(int newIndex) {
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
    ).animate(CurvedAnimation(parent: _snapAnimation, curve: Curves.easeInOut));

    _snapAnimationUpdateListener = () {
      _scrollProgress.value = snapTween.value;
      if (_snapAnimation.isCompleted) {
        _afterSnap();
      }
    };

    _snapAnimation
      ..duration = const Duration(milliseconds: 200)
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

  void _snapToNearest(Velocity flingVelocity) {
    if (!_canMove) {
      return;
    }
    _canMove = false;

    final double velocityValue = widget.direction.isHorizontal
        ? flingVelocity.pixelsPerSecond.dx
        : flingVelocity.pixelsPerSecond.dy;

    if (_touchPoint != null) {
      final moreThanHalf = _scrollProgress.value.abs() > 0.5;
      final isFastSwiping = velocityValue.abs() > 500;
      final reverseFactor = widget.direction.isReverse ? -1 : 1;
      final direction = _scrollProgress.value.sign * reverseFactor;
      final newIndex = _currentIndex + direction;

      final shouldSnap =
          (moreThanHalf || isFastSwiping) &&
          (newIndex >= 0 && newIndex < widget.itemCount);

      final target = shouldSnap ? 1.0 : 0.0;

      final snapTween =
          Tween<double>(
            begin: _scrollProgress.value,
            end: direction > 0 ? target : -target,
          ).animate(
            CurvedAnimation(parent: _snapAnimation, curve: Curves.easeInOut),
          );

      _snapAnimationUpdateListener = () {
        _scrollProgress.value = snapTween.value;
        if (_snapAnimation.isCompleted) {
          _afterSnap();
        }
      };

      _snapAnimation
        ..duration = const Duration(milliseconds: 200)
        ..forward(from: 0);
    }
    _touchPoint = null;
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        _touchPoint = widget.direction.isHorizontal
            ? details.localPosition.dx
            : details.localPosition.dy;
      },
      onPanUpdate: (details) {
        if (!_canMove) {
          return;
        }

        if (_touchPoint != null) {
          final double delta;
          final double fullScrollSize;
          if (widget.direction.isHorizontal) {
            delta = details.delta.dx;
            fullScrollSize = _viewportSize.width;
          } else {
            delta = details.delta.dy;
            fullScrollSize = _viewportSize.height;
          }

          final progress = _scrollProgress.value - (delta / fullScrollSize);
          _scrollProgress.value = progress.clamp(-1.0, 1.0);
        }
      },
      onPanEnd: (details) {
        _snapToNearest(details.velocity);
      },
      onPanCancel: () {
        _snapToNearest(Velocity.zero);
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

            final reverseFactor = widget.direction.isReverse ? -1 : 1;

            return Stack(
              children: [
                for (final item in _loadedWidgets.entries)
                  Transform.translate(
                    key: ValueKey(item.key),
                    offset: Offset(
                      widget.direction.isHorizontal
                          ? ((item.key - _currentIndex - progress) *
                                    reverseFactor) *
                                scrollSize
                          : 0,
                      widget.direction.isVertical
                          ? ((item.key - _currentIndex - progress) *
                                    reverseFactor) *
                                scrollSize
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
