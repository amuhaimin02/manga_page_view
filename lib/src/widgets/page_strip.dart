import 'package:flutter/widgets.dart';

import '../../manga_page_view.dart';
import 'viewport_change.dart';

class MangaPageStrip extends StatefulWidget {
  const MangaPageStrip({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    required this.direction,
    required this.spacing,
    required this.initialPageSize,
    required this.maxPageSize,
    required this.precacheAhead,
    required this.precacheBehind,
    required this.onPageSizeChanged,
  });

  final PageViewDirection direction;
  final double spacing;
  final Size initialPageSize;
  final Size maxPageSize;
  final int precacheAhead;
  final int precacheBehind;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int pageIndex) onPageSizeChanged;

  @override
  State<MangaPageStrip> createState() => MangaPageStripState();
}

class MangaPageStripState extends State<MangaPageStrip> {
  late Map<int, Widget> _loadedWidgets = {};
  late List<Rect> _pageBounds;

  List<Rect> get pageBounds => _pageBounds;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

  @override
  void initState() {
    super.initState();
    _pageBounds = List.filled(
      widget.pageCount,
      Offset.zero & widget.initialPageSize,
    );
    _updatePageBounds();
  }

  @override
  void didUpdateWidget(covariant MangaPageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction ||
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
    final pageCount = widget.pageCount;
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
  }

  void glance(Rect viewRegion) {
    final pageInView = <int>[];
    for (int i = widget.pageCount - 1; i >= 0; i--) {
      final pageBounds = _pageBounds[i];
      if (pageBounds.overlaps(viewRegion)) {
        pageInView.add(i);
      }
    }

    if (pageInView.isNotEmpty) {
      final pageToLoad = Set<int>();
      for (final i in pageInView) {
        if (!_loadedWidgets.containsKey(i)) {
          pageToLoad.add(i);
        }
        // Inverted because we iterate in reverse earlier
        final firstPageVisible = pageInView.last;
        final lastPageVisible = pageInView.first;

        for (int p = 1; p <= widget.precacheAhead; p++) {
          final nextPage = lastPageVisible + p;
          if (nextPage >= 0 &&
              nextPage < widget.pageCount &&
              !_loadedWidgets.containsKey(nextPage)) {
            pageToLoad.add(nextPage);
          }
        }
        for (int p = 1; p <= widget.precacheBehind; p++) {
          final nextPage = firstPageVisible - p;
          if (nextPage >= 0 &&
              nextPage < widget.pageCount &&
              !_loadedWidgets.containsKey(nextPage)) {
            pageToLoad.add(nextPage);
          }
        }
      }
      if (pageToLoad.isNotEmpty) {
        for (final index in pageToLoad) {
          _loadedWidgets[index] = widget.pageBuilder(context, index);
        }
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.direction.isVertical ? _viewportSize.width : null,
      height: widget.direction.isHorizontal ? _viewportSize.height : null,
      child: Flex(
        direction: widget.direction.isVertical
            ? Axis.vertical
            : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: widget.spacing,
        children: [
          if (widget.direction.isReverse)
            for (int i = widget.pageCount - 1; i >= 0; i--)
              _buildPage(context, i)
          else
            for (int i = 0; i < widget.pageCount; i++) _buildPage(context, i),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return Builder(
      builder: (context) {
        return NotificationListener(
          onNotification: (event) {
            if (event is SizeChangedLayoutNotification) {
              _onPageSizeChanged(context, index);
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
              child:
                  _loadedWidgets[index] ??
                  SizedBox.fromSize(size: widget.initialPageSize),
            ),
          ),
        );
      },
    );
  }
}
