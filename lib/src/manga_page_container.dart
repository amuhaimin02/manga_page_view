import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:manga_page_view/src/cached_page.dart';
import 'package:meta/meta.dart';
import '../manga_page_view.dart';

@internal
class MangaPageContainer extends StatefulWidget {
  const MangaPageContainer({
    super.key,
    required this.scrollOffset,
    required this.viewportSize,
    required this.options,
    required this.itemCount,
    required this.itemBuilder,
  });

  final ValueNotifier<Offset> scrollOffset;
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

  @override
  void initState() {
    super.initState();

    widget.scrollOffset.addListener(_updatePageVisibility);

    _loadedPageSize = List.filled(
      widget.itemCount,
      widget.options.initialPageSize,
    );
    _loadedPageBounds = List.filled(widget.itemCount, Rect.zero);
    _refreshPageBounds();
    _updatePageVisibility();
  }

  @override
  void dispose() {
    widget.scrollOffset.removeListener(_updatePageVisibility);
    super.dispose();
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

      if (widget.options.reverseItemOrder) {
        nextPoint = switch (widget.options.scrollDirection) {
          Axis.vertical => nextPoint.translate(0, -pageSize.height),
          Axis.horizontal => nextPoint.translate(-pageSize.width, 0),
        };
      }

      final pageBounds = nextPoint & pageSize;

      _loadedPageBounds[i] = pageBounds;

      nextPoint = switch ((
        widget.options.scrollDirection,
        widget.options.reverseItemOrder,
      )) {
        (Axis.vertical, false) => pageBounds.bottomLeft,
        (Axis.vertical, true) => pageBounds.topLeft,
        (Axis.horizontal, false) => pageBounds.topRight,
        (Axis.horizontal, true) => pageBounds.topLeft,
      };
    }
  }

  void _updatePageVisibility() {
    final scrollOffset = widget.scrollOffset.value;
    final viewportSize = widget.viewportSize;

    final nextVisiblePageIndex = switch ((
      widget.options.scrollDirection,
      widget.options.reverseItemOrder,
    )) {
      (Axis.vertical, false) => _loadedPageBounds.indexWhere(
        (bounds) => bounds.bottom > scrollOffset.dy + viewportSize.height,
      ),
      (Axis.vertical, true) => _loadedPageBounds.indexWhere(
        (bounds) => bounds.top < scrollOffset.dy - viewportSize.height,
      ),
      (Axis.horizontal, false) => _loadedPageBounds.indexWhere(
        (bounds) => bounds.right > scrollOffset.dx + viewportSize.width,
      ),
      (Axis.horizontal, true) => _loadedPageBounds.indexWhere(
        (bounds) => bounds.left < scrollOffset.dx - viewportSize.width,
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
    return Flex(
      direction: widget.options.scrollDirection,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.options.reverseItemOrder)
          for (int i = widget.itemCount - 1; i >= 0; i--) _buildPage(context, i)
        else
          for (int i = 0; i < widget.itemCount; i++) _buildPage(context, i),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return Builder(
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
                maxWidth: widget.options.maxPageSize.width,
                maxHeight: widget.options.maxPageSize.height,
              ),
              child: CachedPage(
                key: ValueKey(index),
                builder: (context) => widget.itemBuilder(context, index),
                visible:
                    index >= _loadedPageStartIndex &&
                    index <= _loadedPageEndIndex,
                initialSize: widget.options.initialPageSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
