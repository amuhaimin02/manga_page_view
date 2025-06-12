import 'package:flutter/widgets.dart';
import 'package:manga_page_view/manga_page_view.dart';
import 'package:meta/meta.dart';
import 'manga_page_continuous_view.dart';

class MangaPageViewController {
  MangaPageViewController();

  @internal
  final pageIndexChangeRequest = ValueNotifier<int?>(null);

  void jumpToPage(int index) {
    pageIndexChangeRequest.value = index;
  }

  void dispose() {
    pageIndexChangeRequest.dispose();
  }
}

class MangaPageView extends StatefulWidget {
  const MangaPageView({
    super.key,
    this.options = const MangaPageViewOptions(),
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
  });

  final MangaPageViewController controller;
  final MangaPageViewOptions options;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Function(int index)? onPageChanged;

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
          onPageChanged: widget.onPageChanged,
        );
      },
    );
  }
}
