import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:meta/meta.dart';
import 'manga_page_continuous_view.dart';
import 'manga_page_screen_view.dart';
import 'widgets/viewport.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    this.onPageChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final Function(int index)? onPageChange;
  final Function(MangaPageViewScrollProgress progress)? onProgressChange;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView> {
  late int _currentPage = 0;
  // late final _pageStore = MangaPageLoaderStore();

  void _onPageChange(int pageIndex) {
    _currentPage = pageIndex;
    widget.onPageChange?.call(pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ViewportChangeListener(
      child: switch (widget.options.mode) {
        MangaPageViewMode.continuous => MangaPageContinuousView(
          initialPageIndex: _currentPage,
          controller: widget.controller,
          options: widget.options,
          pageCount: widget.pageCount,
          pageBuilder: widget.pageBuilder,
          onPageChange: _onPageChange,
          onProgressChange: widget.onProgressChange,
        ),
        MangaPageViewMode.screen => MangaPageScreenView(
          controller: widget.controller,
          initialPageIndex: _currentPage,
          options: widget.options,
          pageCount: widget.pageCount,
          pageBuilder: widget.pageBuilder,
          onPageChange: _onPageChange,
        ),
      },
    );
  }
}

class MangaPageViewController {
  MangaPageViewController();

  @internal
  final pageChangeRequest = ValueNotifier<int?>(null);
  @internal
  final fractionChangeRequest = ValueNotifier<double?>(null);
  @internal
  final offsetChangeRequest = ValueNotifier<double?>(null);

  void jumpToPage(int index) {
    pageChangeRequest.value = index;
  }

  void jumpToFraction(double fraction) {
    fractionChangeRequest.value = fraction;
  }

  // void jumpToOffset(double offset) {
  //   offsetChangeRequest.value = offset;
  // }

  void dispose() {
    pageChangeRequest.dispose();
    fractionChangeRequest.dispose();
    offsetChangeRequest.dispose();
  }
}

class MangaPageViewScrollProgress {
  final int currentPage;
  final int totalPages;
  final double fraction;

  MangaPageViewScrollProgress({
    required this.currentPage,
    required this.totalPages,
    required this.fraction,
  });
}
