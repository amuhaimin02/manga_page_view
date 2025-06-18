import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:manga_page_view/src/widgets/page_carousel.dart';

import 'widgets/interactive_panel.dart';
import 'widgets/page_loader.dart';

class MangaPageScreenView extends StatefulWidget {
  const MangaPageScreenView({
    super.key,
    required this.options,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.viewportSize,
    required this.initialPageIndex,
    this.onPageChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int initialPageIndex;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Size viewportSize;
  final Function(int index)? onPageChange;

  @override
  State<MangaPageScreenView> createState() => _MangaPageScreenViewState();
}

class _MangaPageScreenViewState extends State<MangaPageScreenView> {
  late final _carouselKey = GlobalKey<MangaPageCarouselState>();

  MangaPageCarouselState get _carouselState => _carouselKey.currentState!;

  @override
  void initState() {
    super.initState();
    widget.controller.pageChangeRequest.addListener(_onPageChangeRequest);
  }

  @override
  void dispose() {
    widget.controller.pageChangeRequest.removeListener(_onPageChangeRequest);
    super.dispose();
  }

  void _onPageChangeRequest() {
    final pageIndex = widget.controller.pageChangeRequest.value;
    if (pageIndex != null) {
      _carouselState.jumpToPage(pageIndex);
      widget.controller.pageChangeRequest.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MangaPageCarousel(
      key: _carouselKey,
      initialIndex: widget.initialPageIndex,
      viewportSize: widget.viewportSize,
      direction: widget.options.direction,
      itemCount: widget.pageCount,
      onPageChange: widget.onPageChange,
      itemBuilder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return MangaPageInteractivePanel(
      viewportSize: widget.viewportSize,
      initialZoomLevel: widget.options.initialZoomLevel,
      minZoomLevel: 1,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels
          .where((z) => z >= 1)
          .toList(),
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
      zoomOnFocalPoint: widget.options.zoomOnFocalPoint,
      zoomOvershoot: widget.options.zoomOvershoot,
      child: SizedBox(
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
          children: [widget.pageBuilder(context, index)],
        ),
      ),
    );
  }
}
