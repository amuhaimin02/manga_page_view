import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:manga_page_view/src/widgets/interactive_panel.dart';

class MangaPageScreenView extends StatefulWidget {
  const MangaPageScreenView({
    super.key,
    required this.options,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.viewportSize,
    this.onPageChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Size viewportSize;
  final Function(int index)? onPageChange;

  @override
  State<MangaPageScreenView> createState() => _MangaPageScreenViewState();
}

class _MangaPageScreenViewState extends State<MangaPageScreenView> {
  @override
  Widget build(BuildContext context) {
    return MangaPageInteractivePanel(
      viewportSize: widget.viewportSize,
      initialZoomLevel: widget.options.initialZoomLevel,
      minZoomLevel: widget.options.minZoomLevel,
      maxZoomLevel: widget.options.maxZoomLevel,
      presetZoomLevels: widget.options.presetZoomLevels,
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
      child: _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    return SizedBox(
      width: widget.options.direction.isVertical
          ? widget.viewportSize.width
          : null,
      height: widget.options.direction.isHorizontal
          ? widget.viewportSize.height
          : null,
      child: widget.pageBuilder(context, 0),
    );
  }
}
