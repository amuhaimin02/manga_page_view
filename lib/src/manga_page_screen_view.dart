import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';

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
  final _interactionPanelKey = GlobalKey<MangaPageInteractivePanelState>();

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPageIndex;
    widget.controller.pageChangeRequest.addListener(_onPageChangeRequest);
  }

  @override
  void dispose() {
    widget.controller.pageChangeRequest.removeListener(_onPageChangeRequest);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPageScreenView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _onPageChangeRequest() {
    final pageIndex = widget.controller.pageChangeRequest.value;
    print('page change req: $pageIndex');
    if (pageIndex != null) {
      setState(() {
        _currentPage = pageIndex;
      });
      widget.onPageChange?.call(pageIndex);
      widget.controller.pageChangeRequest.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MangaPageInteractivePanel(
      key: _interactionPanelKey,
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
      child: _buildPage(context, _currentPage),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return SizedBox(
      width: widget.options.direction.isVertical
          ? widget.viewportSize.width
          : null,
      height: widget.options.direction.isHorizontal
          ? widget.viewportSize.height
          : null,
      child: MangaPageLoader(
        key: ValueKey(index),
        builder: (context) => widget.pageBuilder(context, index),
        loaded: true,
        emptyBuilder: (context) => SizedBox(),
      ),
    );
  }
}
