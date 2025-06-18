import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:manga_page_view/src/widgets/page_carousel.dart';

import 'widgets/interactive_panel.dart';
import 'widgets/viewport_change.dart';

class MangaPageScreenView extends StatefulWidget {
  const MangaPageScreenView({
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
  State<MangaPageScreenView> createState() => _MangaPageScreenViewState();
}

class _MangaPageScreenViewState extends State<MangaPageScreenView> {
  late final _carouselKey = GlobalKey<MangaPageCarouselState>();

  MangaPageCarouselState get _carouselState => _carouselKey.currentState!;

  Size get _viewportSize => ViewportSizeProvider.of(context).value;

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
      direction: widget.options.direction,
      itemCount: widget.pageCount,
      onPageChange: widget.onPageChange,
      itemBuilder: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, int index) {
    return MangaPageInteractivePanel(
      // key: ValueKey(index),
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
