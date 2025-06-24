import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'viewport_size.dart';

class PageStrip extends StatefulWidget {
  const PageStrip({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    required this.direction,
    required this.padding,
    required this.spacing,
    required this.initialPageSize,
    required this.precacheAhead,
    required this.precacheBehind,
    required this.widthLimit,
    required this.heightLimit,
  });

  final MangaPageViewDirection direction;
  final EdgeInsets padding;
  final double spacing;
  final Size initialPageSize;
  final int precacheAhead;
  final int precacheBehind;
  final double? widthLimit;
  final double? heightLimit;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;

  @override
  State<PageStrip> createState() => PageStripState();
}

class PageStripState extends State<PageStrip> {
  late Map<int, Widget> _loadedWidgets = {};
  late List<Rect> _pageBounds;

  List<Rect> get pageBounds => _pageBounds;

  Size get _viewportSize => ViewportSize.of(context).value;

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
  void didUpdateWidget(covariant PageStrip oldWidget) {
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
  }

  void _updatePageBounds() {
    final pageCount = widget.pageCount;
    Offset nextPoint = switch (widget.direction) {
      MangaPageViewDirection.up => Offset(0, -widget.padding.bottom),
      MangaPageViewDirection.left => Offset(-widget.padding.right, 0),
      MangaPageViewDirection.down => Offset(0, widget.padding.top),
      MangaPageViewDirection.right => Offset(widget.padding.left, 0),
    };

    for (int i = 0; i < pageCount; i++) {
      final pageSize = _pageBounds[i].size;

      nextPoint = switch (widget.direction) {
        MangaPageViewDirection.up => nextPoint.translate(0, -pageSize.height),
        MangaPageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
        MangaPageViewDirection.down => nextPoint,
        MangaPageViewDirection.right => nextPoint,
      };

      final pageBounds = nextPoint & pageSize;

      _pageBounds[i] = pageBounds;

      final spacing = widget.spacing;
      nextPoint = switch (widget.direction) {
        MangaPageViewDirection.up => pageBounds.topLeft.translate(0, -spacing),
        MangaPageViewDirection.left => pageBounds.topLeft.translate(
          -spacing,
          0,
        ),
        MangaPageViewDirection.down => pageBounds.bottomLeft.translate(
          0,
          spacing,
        ),
        MangaPageViewDirection.right => pageBounds.topRight.translate(
          spacing,
          0,
        ),
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
        setState(() {
          for (final index in pageToLoad) {
            _loadedWidgets[index] = widget.pageBuilder(context, index);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double? containerWidth = null;
    double? containerHeight = null;

    // Limit cross-axis size if specified. By default they follow viewport size
    if (widget.direction.isVertical) {
      containerWidth = min(
        widget.widthLimit ?? double.infinity,
        _viewportSize.width,
      );
    } else if (widget.direction.isHorizontal) {
      containerHeight = min(
        widget.heightLimit ?? double.infinity,
        _viewportSize.height,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: containerWidth ?? double.infinity,
        maxHeight: containerHeight ?? double.infinity,
      ),
      child: Padding(
        padding: widget.padding,
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
            child:
                _loadedWidgets[index] ??
                SizedBox.fromSize(size: widget.initialPageSize),
          ),
        );
      },
    );
  }
}
