import 'package:flutter/widgets.dart';

import '../manga_page_view.dart';
import 'widgets/interactive_panel.dart';
import 'widgets/page_strip.dart';

class MangaPageContinuousView extends StatefulWidget {
  const MangaPageContinuousView({
    super.key,
    required this.controller,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
    required this.viewportSize,
    this.onPageChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Size viewportSize;
  final Function(int index)? onPageChange;
  final Function(MangaPageViewScrollProgress progress)? onProgressChange;

  @override
  State<MangaPageContinuousView> createState() =>
      _MangaPageContinuousViewState();
}

class _MangaPageContinuousViewState extends State<MangaPageContinuousView> {
  final _interactionPanelKey = GlobalKey<MangaPageInteractivePanelState>();
  double _scrollBoundMin = 0;
  double _scrollBoundMax = 0;
  Offset _currentOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.fractionChangeRequest.addListener(
      _onFractionChangeRequest,
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.fractionChangeRequest.removeListener(
      _onFractionChangeRequest,
    );
  }

  MangaPageInteractivePanelState get _panelState =>
      _interactionPanelKey.currentState!;

  void _onFractionChangeRequest() {
    final fraction = widget.controller.fractionChangeRequest.value;

    if (fraction != null) {
      final targetOffset = _fractionToOffset(fraction);
      _panelState.jumpTo(targetOffset);
      widget.controller.fractionChangeRequest.value = null;
    }
  }

  void _handleInteraction(ScrollInfo info) {
    switch (widget.options.direction) {
      case PageViewDirection.up:
        _scrollBoundMin = info.scrollableRegion.bottom;
        _scrollBoundMax = info.scrollableRegion.top;
      case PageViewDirection.down:
        _scrollBoundMin = info.scrollableRegion.top;
        _scrollBoundMax = info.scrollableRegion.bottom;
      case PageViewDirection.left:
        _scrollBoundMin = info.scrollableRegion.right;
        _scrollBoundMax = info.scrollableRegion.left;
      case PageViewDirection.right:
        _scrollBoundMin = info.scrollableRegion.left;
        _scrollBoundMax = info.scrollableRegion.right;
    }

    final fraction = _offsetToFraction(info.offset);
    _currentOffset = info.offset;

    widget.onProgressChange?.call(
      MangaPageViewScrollProgress(
        currentPage: 1,
        totalPages: 1,
        fraction: fraction,
      ),
    );
  }

  double _offsetToFraction(Offset offset) {
    final double current;
    final double min;
    final double max;

    switch (widget.options.direction) {
      case PageViewDirection.up:
        current = offset.dy;
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.down:
        current = offset.dy;
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
      case PageViewDirection.left:
        current = offset.dx;
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.right:
        current = offset.dx;
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
    }
    return ((current - min) / (max - min)).clamp(0, 1);
  }

  Offset _fractionToOffset(double fraction) {
    final double target;
    final double min;
    final double max;

    switch (widget.options.direction) {
      case PageViewDirection.up:
      case PageViewDirection.left:
        min = _scrollBoundMax;
        max = _scrollBoundMin;
        break;
      case PageViewDirection.down:
      case PageViewDirection.right:
        min = _scrollBoundMin;
        max = _scrollBoundMax;
        break;
    }
    target = min + (max - min) * fraction;

    return switch (widget.options.direction) {
      PageViewDirection.up ||
      PageViewDirection.down => Offset(_currentOffset.dx, target),
      PageViewDirection.left ||
      PageViewDirection.right => Offset(target, _currentOffset.dy),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MangaPageInteractivePanel(
      key: _interactionPanelKey,
      initialZoomLevel: widget.options.initialZoomLevel,
      minZoomLevel: widget.options.minZoomLevel,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels,
      zoomOnFocalPoint: widget.options.zoomOnFocalPoint,
      zoomOvershoot: widget.options.zoomOvershoot,
      verticalOverscroll:
          widget.options.direction.isVertical &&
              widget.options.mainAxisOverscroll ||
          widget.options.direction.isHorizontal &&
              widget.options.crossAxisOverscroll,
      horizontalOverscroll:
          widget.options.direction.isHorizontal &&
              widget.options.mainAxisOverscroll ||
          widget.options.direction.isVertical &&
              widget.options.crossAxisOverscroll,
      alignment: switch (widget.options.direction) {
        PageViewDirection.down => PanelAlignment.top,
        PageViewDirection.right => PanelAlignment.left,
        PageViewDirection.up => PanelAlignment.bottom,
        PageViewDirection.left => PanelAlignment.right,
      },
      viewportSize: widget.viewportSize,
      child: MangaPageStrip(
        viewportSize: widget.viewportSize,
        direction: widget.options.direction,
        spacing: widget.options.spacing,
        initialPageSize: widget.options.initialPageSize,
        maxPageSize: widget.options.maxPageSize,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
      onInteract: _handleInteraction,
    );
  }
}
