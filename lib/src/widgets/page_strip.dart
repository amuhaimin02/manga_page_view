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
  });

  final Size viewportSize; // TODO: Remove?
  final PageViewDirection direction;
  final double spacing;
  final Size initialPageSize;
  final Size maxPageSize;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<MangaPageStrip> createState() => MangaPageStripState();
}

class MangaPageStripState extends State<MangaPageStrip> {
  late List<bool> _pageLoaded;
  late List<Rect> _pageBounds;
  late Size _containerSize;

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
      if (_pageLoaded[i]) {
        continue;
      }

      final pageBounds = _pageBounds[i];
      if (pageBounds.overlaps(viewRegion)) {
        (pageToLoad ??= [])..add(i);
      }
    }

    if (pageToLoad != null) {
      setState(() {
        for (final pageIndex in pageToLoad!) {
          _pageLoaded[pageIndex] = true;
        }
      });
    }
  }

  Rect getPageBounds(int pageIndex) {
    return _pageBounds[pageIndex];
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

//
// @internal
// class MangaPageContainer extends StatefulWidget {
//   const MangaPageContainer({
//     super.key,
//     required this.viewportSize,
//     required this.options,
//     required this.itemCount,
//     required this.itemBuilder,
//   });
//
//   final Size viewportSize;
//   final MangaPageViewOptions options;
//   final int itemCount;
//   final IndexedWidgetBuilder itemBuilder;
//
//   @override
//   State<MangaPageContainer> createState() => MangaPageContainerState();
// }
//
// class MangaPageContainerState extends State<MangaPageContainer> {
//   PageViewDirection get direction => widget.options.direction;
//
//   final manager = _MangaPageContainerRegionManager();
//
//   @override
//   void initState() {
//     super.initState();
//     manager.addListener(_onContainerSizeUpdate);
//     manager.setup(
//       widget.itemCount,
//       widget.options.initialPageSize,
//       widget.options.spacing,
//       widget.options.direction,
//     );
//   }
//
//   @override
//   void dispose() {
//     manager.removeListener(_onContainerSizeUpdate);
//     super.dispose();
//   }
//
//   @override
//   void didUpdateWidget(covariant MangaPageContainer oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.options.direction != oldWidget.options.direction) {
//       manager.reorient(widget.options.direction);
//     }
//   }
//
//   void _onContainerSizeUpdate() {
//     // _updatePageVisibility();
//   }
//
//   // int offsetToPageIndex(Offset offset, PageViewGravity gravity) {
//   //   Rect transform(Rect bounds) {
//   //     return widget.scrollInfo.transformZoom(bounds, widget.viewportSize);
//   //   }
//   //
//   //   final viewportSize = widget.viewportSize;
//   //   final viewportCenter = viewportSize.center(Offset.zero);
//   //
//   //   final isBoundInRange = switch (widget.options.direction) {
//   //     PageViewDirection.down =>
//   //       (Rect b) =>
//   //           gravity.select(
//   //             start: b.top,
//   //             center: b.center.dy - viewportCenter.dy,
//   //             end: b.bottom - viewportSize.height,
//   //           ) >
//   //           offset.dy / zoomLevel,
//   //     PageViewDirection.up =>
//   //       (Rect b) =>
//   //           gravity.select(
//   //             start: -b.bottom,
//   //             center: -b.center.dy - viewportCenter.dy,
//   //             end: -b.top - viewportSize.height,
//   //           ) >
//   //           offset.dy / zoomLevel,
//   //     PageViewDirection.right =>
//   //       (Rect b) =>
//   //           gravity.select(
//   //             start: b.left,
//   //             center: b.center.dx - viewportCenter.dx,
//   //             end: b.right - viewportSize.width,
//   //           ) >
//   //           offset.dx / zoomLevel,
//   //     PageViewDirection.left =>
//   //       (Rect b) =>
//   //           gravity.select(
//   //             start: -b.right,
//   //             center: -b.center.dx - viewportCenter.dx,
//   //             end: -b.left - viewportSize.width,
//   //           ) >
//   //           offset.dx / zoomLevel,
//   //   };
//   //
//   //   int foundPageIndex = -1;
//   //
//   //   for (Rect pageBounds in manager.allBounds.map(transform)) {
//   //     if (isBoundInRange(pageBounds)) {
//   //       break;
//   //     }
//   //     foundPageIndex += 1;
//   //   }
//   //   return foundPageIndex;
//   // }
//   //
//   // Offset pageIndexToOffset(int index, PageViewGravity gravity) {
//   //   final pageBounds = widget.scrollInfo.transformZoom(
//   //     manager.getBounds(index),
//   //     widget.viewportSize,
//   //   );
//   //   final viewportSize = widget.viewportSize;
//   //   final viewportCenter = viewportSize.center(Offset.zero);
//   //
//   //   return switch (direction) {
//   //     PageViewDirection.down => Offset(
//   //       0,
//   //       gravity.select(
//   //         start: pageBounds.top,
//   //         center: pageBounds.center.dy - viewportCenter.dy,
//   //         end: pageBounds.bottom - viewportSize.height,
//   //       ),
//   //     ),
//   //     PageViewDirection.up => Offset(
//   //       0,
//   //       gravity.select(
//   //         start: -pageBounds.bottom,
//   //         center: -pageBounds.center.dy - viewportCenter.dy,
//   //         end: -pageBounds.top - viewportSize.height,
//   //       ),
//   //     ),
//   //     PageViewDirection.right => Offset(
//   //       gravity.select(
//   //         start: pageBounds.left,
//   //         center: pageBounds.center.dx - viewportCenter.dx,
//   //         end: pageBounds.right - viewportSize.width,
//   //       ),
//   //       0,
//   //     ),
//   //     PageViewDirection.left => Offset(
//   //       gravity.select(
//   //         start: -pageBounds.right,
//   //         center: -pageBounds.center.dx - viewportCenter.dx,
//   //         end: -pageBounds.left - viewportSize.width,
//   //       ),
//   //       0,
//   //     ),
//   //   };
//   // }
//
//   void _onPageSizeChanged(BuildContext context, int pageIndex) {
//     final pageRenderBox = context.findRenderObject() as RenderBox;
//     final pageSize = pageRenderBox.size;
//     manager.updatePage(pageIndex, pageSize);
//   }
//   //
//   // void _updatePageVisibility() {
//   //   final viewportSize = widget.viewportSize;
//   //
//   //   final nextVisiblePageIndex = offsetToPageIndex(
//   //     (offset * zoomLevel).translate(viewportSize.width, viewportSize.height),
//   //     PageViewGravity.start,
//   //   );
//   //
//   //   if (nextVisiblePageIndex > _loadedPageEndIndex) {
//   //     setState(() {
//   //       _loadedPageEndIndex = nextVisiblePageIndex;
//   //     });
//   //   }
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     return _buildContainer(context);
//   }
//
//   Widget _buildContainer(BuildContext context) {
//     return SizedBox(
//       width: direction.isVertical ? widget.viewportSize.width : null,
//       height: direction.isHorizontal ? widget.viewportSize.height : null,
//       child: Padding(
//         padding: const EdgeInsets.all(80.0),
//         child: Flex(
//           direction: direction.isVertical ? Axis.vertical : Axis.horizontal,
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           spacing: widget.options.spacing,
//           children: [
//             if (widget.options.direction.isReverse)
//               for (int i = widget.itemCount - 1; i >= 0; i--)
//                 _buildPage(context, i)
//             else
//               for (int i = 0; i < widget.itemCount; i++) _buildPage(context, i),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPage(BuildContext context, int index) {
//     return Builder(
//       key: ValueKey(index),
//       builder: (context) {
//         return NotificationListener(
//           onNotification: (event) {
//             if (event is SizeChangedLayoutNotification) {
//               SchedulerBinding.instance.addPostFrameCallback((_) {
//                 _onPageSizeChanged(context, index);
//               });
//               return true;
//             }
//             return false;
//           },
//           child: SizeChangedLayoutNotifier(
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: widget.options.maxPageSize.width,
//                 maxHeight: widget.options.maxPageSize.height,
//               ),
//               child: CachedPage(
//                 builder: (context) => widget.itemBuilder(context, index),
//                 visible: true,
//                 initialSize: widget.options.initialPageSize,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _MangaPageContainerRegionManager extends ChangeNotifier {
//   int _pageCount = 0;
//   PageViewDirection _direction = PageViewDirection.down;
//
//   List<Rect> _pageBounds = [];
//   Size _containerSize = Size.zero;
//   double _spacing = 0;
//
//   void setup(
//       int totalPages,
//       Size initialSize,
//       double spacing,
//       PageViewDirection direction,
//       ) {
//     _pageCount = totalPages;
//     _spacing = spacing;
//     _direction = direction;
//     _pageBounds = List.filled(totalPages, Offset.zero & initialSize);
//     _recalculate();
//   }
//
//   Rect getBounds(int pageIndex) {
//     return _pageBounds[pageIndex];
//   }
//
//   void updatePage(int pageIndex, Size pageSize) {
//     _pageBounds[pageIndex] = Offset.zero & pageSize;
//     _recalculate();
//   }
//
//   void reorient(PageViewDirection newDirection) {
//     _direction = newDirection;
//     _recalculate();
//   }
//
//   Size get containerSize => _containerSize;
//
//   Iterable<Rect> get allBounds => _pageBounds;
//
//   void _recalculate() {
//     Offset nextPoint = Offset.zero;
//     for (int i = 0; i < _pageCount; i++) {
//       final pageSize = _pageBounds[i].size;
//
//       nextPoint = switch (_direction) {
//         PageViewDirection.up => nextPoint.translate(0, -pageSize.height),
//         PageViewDirection.left => nextPoint.translate(-pageSize.width, 0),
//         PageViewDirection.down => nextPoint,
//         PageViewDirection.right => nextPoint,
//       };
//
//       final pageBounds = nextPoint & pageSize;
//
//       _pageBounds[i] = pageBounds;
//
//       nextPoint = switch (_direction) {
//         PageViewDirection.up => pageBounds.topLeft.translate(0, -_spacing),
//         PageViewDirection.left => pageBounds.topLeft.translate(-_spacing, 0),
//         PageViewDirection.down => pageBounds.bottomLeft.translate(0, _spacing),
//         PageViewDirection.right => pageBounds.topRight.translate(_spacing, 0),
//       };
//     }
//
//     final overallBounds = _pageBounds.first.expandToInclude(_pageBounds.last);
//     _containerSize = overallBounds.size;
//
//     notifyListeners();
//   }
// }
//
