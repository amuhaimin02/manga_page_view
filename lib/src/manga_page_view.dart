import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:meta/meta.dart';
import 'manga_page_continuous_view.dart';

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChange,
    this.onProgressChange,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Function(int index)? onPageChange;
  final Function(MangaPageViewScrollProgress progress)? onProgressChange;

  @override
  State<MangaPageView> createState() => _MangaPageViewState();
}

class _MangaPageViewState extends State<MangaPageView> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MangaPageContinuousView(
          controller: widget.controller,
          options: widget.options,
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
          viewportSize: constraints.biggest,
          onPageChange: widget.onPageChange,
          onProgressChange: widget.onProgressChange,
        );
      },
    );
  }
}

class MangaPageViewController {
  MangaPageViewController();

  @internal
  final pageIndexChangeRequest = ValueNotifier<int?>(null);
  @internal
  final fractionChangeRequest = ValueNotifier<double?>(null);
  @internal
  final offsetChangeRequest = ValueNotifier<double?>(null);

  void jumpToPage(int index) {
    pageIndexChangeRequest.value = index;
  }

  void jumpToFraction(double fraction) {
    fractionChangeRequest.value = fraction;
  }

  void jumpToOffset(double offset) {
    offsetChangeRequest.value = offset;
  }

  void dispose() {
    pageIndexChangeRequest.dispose();
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
