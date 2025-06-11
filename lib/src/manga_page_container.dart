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
  State<MangaPageContainer> createState() => _MangaPageContainerState();
}

class _MangaPageContainerState extends State<MangaPageContainer> {
  int _loadedPageStartIndex = 0;
  int _loadedPageEndIndex = 0;
  late List<Size> _loadedPageSize;
  late List<Rect> _loadedPageBounds;

  Offset get offset => widget.scrollInfo.offset.value;
  double get zoomLevel => widget.scrollInfo.zoomLevel.value;

  @override
  void initState() {
    super.initState();

    widget.scrollInfo.addListener(_updatePageVisibility);

    _loadedPageSize = List.filled(
      widget.itemCount,
      widget.options.initialPageSize,
    );
    _loadedPageBounds = List.filled(widget.itemCount, Rect.zero);

    SchedulerBinding.instance.addPostFrameCallback((_) => _refreshPageBounds());
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

    final nextVisiblePageIndex = switch (widget.options.direction) {
      PageViewDirection.down => _loadedPageBounds.indexWhere(
        (bounds) => bounds.bottom > offset.dy + viewportSize.height / zoomLevel,
      ),
      PageViewDirection.up => _loadedPageBounds.indexWhere(
        (bounds) => bounds.top < offset.dy - viewportSize.height / zoomLevel,
      ),
      PageViewDirection.right => _loadedPageBounds.indexWhere(
        (bounds) => bounds.right > offset.dx + viewportSize.width / zoomLevel,
      ),
      PageViewDirection.left => _loadedPageBounds.indexWhere(
        (bounds) => bounds.left < offset.dx - viewportSize.width / zoomLevel,
      ),
    };

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
      width: widget.options.direction.isVertical
          ? widget.viewportSize.width
          : null,
      height: widget.options.direction.isHorizontal
          ? widget.viewportSize.height
          : null,
      child: Flex(
        direction: widget.options.direction.isVertical
            ? Axis.vertical
            : Axis.horizontal,
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
