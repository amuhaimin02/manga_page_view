import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import '../manga_page_view_controller.dart';
import 'interactive_panel.dart';
import 'page_carousel.dart';
import 'viewport_size.dart';

/// Base widget for paged view
class MangaPagePagedView extends StatefulWidget {
  const MangaPagePagedView({
    super.key,
    required this.options,
    required this.direction,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.initialPageIndex,
    this.onPageChange,
    this.onProgressChange,
    this.onZoomChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewDirection direction;
  final MangaPageViewOptions options;
  final int? initialPageIndex;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(double progress)? onProgressChange;
  final Function(double zoomLevel)? onZoomChange;

  @override
  State<MangaPagePagedView> createState() => _MangaPagePagedViewState();
}

class _MangaPagePagedViewState extends State<MangaPagePagedView> {
  late final _carouselKey = GlobalKey<PageCarouselState>();
  final Map<int, GlobalKey<InteractivePanelState>> _panelKeys = {};

  PageCarouselState get _carouselState => _carouselKey.currentState!;

  InteractivePanelState? get _activePanelState =>
      _panelKeys[_currentPage]?.currentState;

  Size get _viewportSize => ViewportSize.of(context).value;

  late int _currentPage = widget.initialPageIndex ?? 0;
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
    _controllerIntentStream?.cancel();
    super.dispose();
  }

  void _onControllerIntent(ControllerChangeIntent intent) {
    switch (intent) {
      case PageChangeIntent(:final index, :final duration, :final curve):
        if (index < 0 || index >= widget.pageCount) return;

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
      case ScrollDeltaChangeIntent(:final delta, :final duration, :final curve):
        if (_activePanelState == null) return;
        final targetOffset = _scrollBy(delta);
        if (duration > Duration.zero) {
          _activePanelState!.animateToOffset(targetOffset, duration, curve);
        } else {
          _activePanelState!.jumpToOffset(targetOffset);
        }
      case PanDeltaChangeIntent(:final delta, :final duration, :final curve):
        if (_activePanelState == null) return;
        final targetOffset = _panBy(delta);
        if (duration > Duration.zero) {
          _activePanelState!.animateToOffset(targetOffset, duration, curve);
        } else {
          _activePanelState!.jumpToOffset(targetOffset);
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

  Offset _scrollBy(double delta) {
    final currentOffset = _activePanelState!.offset;
    final scrollableRegion = _activePanelState!.scrollableRegion;
    final Offset newOffset;

    switch (widget.direction) {
      case MangaPageViewDirection.down:
        newOffset = Offset(
          currentOffset.dx,
          (currentOffset.dy + delta).clamp(
            scrollableRegion.top,
            scrollableRegion.bottom,
          ),
        );
        break;
      case MangaPageViewDirection.up:
        newOffset = Offset(
          currentOffset.dx,
          (currentOffset.dy - delta).clamp(
            scrollableRegion.bottom,
            scrollableRegion.top,
          ),
        );
        break;
      case MangaPageViewDirection.right:
        newOffset = Offset(
          (currentOffset.dx + delta).clamp(
            scrollableRegion.left,
            scrollableRegion.right,
          ),
          currentOffset.dy,
        );
        break;
      case MangaPageViewDirection.left:
        newOffset = Offset(
          (currentOffset.dx - delta).clamp(
            scrollableRegion.right,
            scrollableRegion.left,
          ),
          currentOffset.dy,
        );
        break;
    }
    return newOffset;
  }

  Offset _panBy(Offset delta) {
    final currentOffset = _activePanelState!.offset;
    final newOffset = currentOffset + delta;
    return newOffset;
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
    return PageCarousel(
      key: _carouselKey,
      initialIndex: widget.initialPageIndex ?? 0,
      direction: widget.direction,
      itemCount: widget.pageCount,
      onPageChange: _onPageChange,
      itemBuilder: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, int index) {
    // Create keys for panel if not exists. We need them to manipulate the panel states later on.
    final panelKey = _panelKeys.putIfAbsent(
      index,
      GlobalKey<InteractivePanelState>.new,
    );
    return InteractivePanel(
      key: panelKey,
      initialZoomLevel: widget.options.initialZoomLevel,
      initialFadeInDuration: widget.options.initialFadeInDuration,
      initialFadeInCurve: widget.options.initialFadeInCurve,
      minZoomLevel: widget.options.minZoomLevel,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels,
      verticalOverscroll: widget.direction.isVertical &&
              widget.options.mainAxisOverscroll ||
          widget.direction.isHorizontal && widget.options.crossAxisOverscroll,
      horizontalOverscroll:
          widget.direction.isHorizontal && widget.options.mainAxisOverscroll ||
              widget.direction.isVertical && widget.options.crossAxisOverscroll,
      anchor: switch (widget.direction) {
        MangaPageViewDirection.down => MangaPageViewEdge.top,
        MangaPageViewDirection.right => MangaPageViewEdge.left,
        MangaPageViewDirection.up => MangaPageViewEdge.bottom,
        MangaPageViewDirection.left => MangaPageViewEdge.right,
      },
      zoomOnFocalPoint: widget.options.zoomOnFocalPoint,
      zoomOvershoot: widget.options.zoomOvershoot,
      panCheckAxis: widget.direction.axis,
      onScroll: (offset, zoomLevel) => _onPanelScroll(index, offset, zoomLevel),
      child: _buildPage(context, index),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return ValueListenableBuilder(
      valueListenable: ViewportSize.of(context),
      builder: (context, value, child) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _viewportSize.width,
            maxHeight: _viewportSize.height,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: widget.options.padding,
        child: widget.pageBuilder(context, index),
      ),
    );
  }
}
