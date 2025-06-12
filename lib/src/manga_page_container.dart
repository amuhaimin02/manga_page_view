import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:manga_page_view/src/cached_page.dart';
import 'package:meta/meta.dart';
import '../manga_page_view.dart';

@internal
class MangaPageContainer extends StatefulWidget {
  const MangaPageContainer({
    super.key,
    required this.scrollInfo,
    required this.viewportSize,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
  });

  final ScrollInfo scrollInfo;
  final Size viewportSize;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<MangaPageContainer> createState() => MangaPageContainerState();
}

class MangaPageContainerState extends State<MangaPageContainer> {
  Offset get offset => widget.scrollInfo.offset.value;
  double get zoomLevel => widget.scrollInfo.zoomLevel.value;
  PageViewDirection get direction => widget.options.direction;

  int _loadedPageStartIndex = 0;
  int _loadedPageEndIndex = 0;
  late List<Size> _loadedPageSize;
  late List<Rect> _loadedPageBounds;

  @override
  void initState() {
    super.initState();
    widget.scrollInfo.addListener(_updatePageVisibility);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadedPageSize = List.filled(
        widget.itemCount,
        widget.options.initialPageSize,
      );
      _loadedPageBounds = List.filled(widget.itemCount, Rect.zero);
      _refreshPageBounds();
    });
  }

  @override
  void dispose() {
    widget.scrollInfo.removeListener(_updatePageVisibility);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPageContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.direction != oldWidget.options.direction) {
      _refreshPageBounds();
    }
  }

  int offsetToPageIndex(Offset offset, PageViewGravity gravity) {
    Rect transform(Rect bounds) {
      return widget.scrollInfo.transformZoom(bounds, widget.viewportSize);
    }

    final viewportSize = widget.viewportSize;
    final viewportCenter = viewportSize.center(Offset.zero);

    final isBoundInRange = switch (widget.options.direction) {
      PageViewDirection.down =>
        (Rect b) =>
            gravity.select(
              start: b.top,
              center: b.center.dy - viewportCenter.dy,
              end: b.bottom - viewportSize.height,
            ) >
            offset.dy / zoomLevel,
      PageViewDirection.up =>
        (Rect b) =>
            gravity.select(
              start: -b.bottom,
              center: -b.center.dy - viewportCenter.dy,
              end: -b.top - viewportSize.height,
            ) >
            offset.dy / zoomLevel,
      PageViewDirection.right =>
        (Rect b) =>
            gravity.select(
              start: b.left,
              center: b.center.dx - viewportCenter.dx,
              end: b.right - viewportSize.width,
            ) >
            offset.dx / zoomLevel,
      PageViewDirection.left =>
        (Rect b) =>
            gravity.select(
              start: -b.right,
              center: -b.center.dx - viewportCenter.dx,
              end: -b.left - viewportSize.width,
            ) >
            offset.dx / zoomLevel,
    };

    int foundPageIndex = -1;

    for (Rect pageBounds in _loadedPageBounds.map(transform)) {
      if (isBoundInRange(pageBounds)) {
        break;
      }
      foundPageIndex += 1;
    }
    return foundPageIndex;
  }

  Offset pageIndexToOffset(int index, PageViewGravity gravity) {
    final pageBounds = widget.scrollInfo.transformZoom(
      _loadedPageBounds[index],
      widget.viewportSize,
    );
    final viewportSize = widget.viewportSize;
    final viewportCenter = viewportSize.center(Offset.zero);

    return switch (direction) {
      PageViewDirection.down => Offset(
        0,
        gravity.select(
          start: pageBounds.top,
          center: pageBounds.center.dy - viewportCenter.dy,
          end: pageBounds.bottom - viewportSize.height,
        ),
      ),
      PageViewDirection.up => Offset(
        0,
        gravity.select(
          start: -pageBounds.bottom,
          center: -pageBounds.center.dy - viewportCenter.dy,
          end: -pageBounds.top - viewportSize.height,
        ),
      ),
      PageViewDirection.right => Offset(
        gravity.select(
          start: pageBounds.left,
          center: pageBounds.center.dx - viewportCenter.dx,
          end: pageBounds.right - viewportSize.width,
        ),
        0,
      ),
      PageViewDirection.left => Offset(
        gravity.select(
          start: -pageBounds.right,
          center: -pageBounds.center.dx - viewportCenter.dx,
          end: -pageBounds.left - viewportSize.width,
        ),
        0,
      ),
    };
  }

  void _onPageSizeChanged(BuildContext context, int pageIndex) {
    final pageRenderBox = context.findRenderObject() as RenderBox;
    final pageSize = pageRenderBox.size;
    _loadedPageSize[pageIndex] = pageSize;
    _refreshPageBounds();
  }

  void _refreshPageBounds() {
    Offset nextPoint = Offset.zero;
    for (int i = 0; i < widget.itemCount; i++) {
      final pageSize = _loadedPageSize[i];

      nextPoint = switch (widget.options.direction) {
        PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        PageViewDirection.down => nextPoint,
        PageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _loadedPageBounds[i] = pageBounds;

      nextPoint = switch (widget.options.direction) {
        PageViewDirection.up => pageBounds.topLeft,
        PageViewDirection.left => pageBounds.topLeft,
        PageViewDirection.down => pageBounds.bottomLeft,
        PageViewDirection.right => pageBounds.topRight,
      };
    }

    _updatePageVisibility();
  }

  void _updatePageVisibility() {
    final viewportSize = widget.viewportSize;

    final nextVisiblePageIndex = offsetToPageIndex(
      (offset * zoomLevel).translate(viewportSize.width, viewportSize.height),
      PageViewGravity.start,
    );

    if (nextVisiblePageIndex > _loadedPageEndIndex) {
      setState(() {
        _loadedPageEndIndex = nextVisiblePageIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContainer(context);
  }

  Widget _buildContainer(BuildContext context) {
    return SizedBox(
      width: direction.isVertical ? widget.viewportSize.width : null,
      height: direction.isHorizontal ? widget.viewportSize.height : null,
      child: Flex(
        direction: direction.isVertical ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.options.direction.isReverse)
            for (int i = widget.itemCount - 1; i >= 0; i--)
              _buildPage(context, i)
          else
            for (int i = 0; i < widget.itemCount; i++) _buildPage(context, i),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return Builder(
      key: ValueKey(index),
      builder: (context) {
        final cacheRangeEnd = min(
          _loadedPageEndIndex + widget.options.precacheOverhead,
          widget.itemCount - 1,
        );
        final cacheRangeStart = max(0, 0);

        final isPageVisible =
            index >= cacheRangeStart && index <= cacheRangeEnd;

        return NotificationListener(
          onNotification: (event) {
            if (event is SizeChangedLayoutNotification) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _onPageSizeChanged(context, index);
              });
              return true;
            }
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.options.maxPageSize.width,
                maxHeight: widget.options.maxPageSize.height,
              ),
              child: CachedPage(
                builder: (context) => widget.itemBuilder(context, index),
                visible: isPageVisible,
                initialSize: widget.options.initialPageSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
