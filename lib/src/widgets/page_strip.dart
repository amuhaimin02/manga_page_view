import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import 'cached_page.dart';

class MangaPageStrip extends StatefulWidget {
  const MangaPageStrip({
    super.key,
    required this.viewportSize,
    required this.itemCount,
    required this.itemBuilder,
    required this.direction,
    required this.spacing,
    required this.initialPageSize,
    required this.maxPageSize,
    required this.precacheOverhead,
    required this.onPageSizeChanged,
  });

  final Size viewportSize; // TODO: Remove?
  final PageViewDirection direction;
  final double spacing;
  final Size initialPageSize;
  final Size maxPageSize;
  final int precacheOverhead;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Function(int pageIndex) onPageSizeChanged;

  @override
  State<MangaPageStrip> createState() => MangaPageStripState();
}

class MangaPageStripState extends State<MangaPageStrip> {
  late List<bool> _pageLoaded;
  late List<Rect> _pageBounds;
  late Size _containerSize;

  List<Rect> get pageBounds => _pageBounds;

  @override
  void initState() {
    super.initState();
    _pageLoaded = List.filled(widget.itemCount, false);
    _pageBounds = List.filled(
      widget.itemCount,
      Offset.zero & widget.initialPageSize,
    );
    _updatePageBounds();
  }

  @override
  void didUpdateWidget(covariant MangaPageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction &&
        widget.spacing != oldWidget.spacing) {
      _updatePageBounds();
    }
  }

  void _onPageSizeChanged(BuildContext context, int index) {
    final pageSize = (context.findRenderObject() as RenderBox).size;
    _pageBounds[index] = Offset.zero & pageSize;
    _updatePageBounds();
    widget.onPageSizeChanged(index);
  }

  void _updatePageBounds() {
    final pageCount = widget.itemCount;
    Offset nextPoint = Offset.zero;
    for (int i = 0; i < pageCount; i++) {
      final pageSize = _pageBounds[i].size;

      nextPoint = switch (widget.direction) {
        PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        PageViewDirection.down => nextPoint,
        PageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _pageBounds[i] = pageBounds;

      final spacing = widget.spacing;
      nextPoint = switch (widget.direction) {
        PageViewDirection.up => pageBounds.topLeft.translate(0, -spacing),
        PageViewDirection.left => pageBounds.topLeft.translate(-spacing, 0),
        PageViewDirection.down => pageBounds.bottomLeft.translate(0, spacing),
        PageViewDirection.right => pageBounds.topRight.translate(spacing, 0),
      };
    }

    final overallBounds = _pageBounds.first.expandToInclude(_pageBounds.last);
    _containerSize = overallBounds.size;
  }

  void glance(Rect viewRegion) {
    List<int>? pageToLoad;
    for (int i = widget.itemCount - 1; i >= 0; i--) {
      final pageBounds = _pageBounds[i];
      if (pageBounds.overlaps(viewRegion)) {
        if (pageToLoad == null) {
          pageToLoad = [];

          // Preload in advance if application
          if (widget.precacheOverhead > 0) {
            for (int p = 1; p <= widget.precacheOverhead; p++) {
              final nextPageLoad = i + p;
              if (nextPageLoad >= 0 && nextPageLoad < widget.itemCount) {
                _pageLoaded[nextPageLoad] = true;
              }
            }
          }
        }
        pageToLoad.add(i);
      }
    }

    if (pageToLoad != null) {
      for (final pageIndex in pageToLoad) {
        _pageLoaded[pageIndex] = true;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.direction.isVertical ? widget.viewportSize.width : null,
      height: widget.direction.isHorizontal ? widget.viewportSize.height : null,
      child: Flex(
        direction: widget.direction.isVertical
            ? Axis.vertical
            : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: widget.spacing,
        children: [
          if (widget.direction.isReverse)
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
                maxWidth: widget.maxPageSize.width,
                maxHeight: widget.maxPageSize.height,
              ),
              child: CachedPage(
                builder: (context) => widget.itemBuilder(context, index),
                visible: _pageLoaded[index],
                initialSize: widget.initialPageSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
