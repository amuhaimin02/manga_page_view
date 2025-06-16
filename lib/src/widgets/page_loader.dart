import 'package:flutter/cupertino.dart';

class MangaPageLoaderProvider extends InheritedWidget {
  MangaPageLoaderProvider({required super.child, required this.store});

  final MangaPageLoaderStore store;

  static MangaPageLoaderStore of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MangaPageLoaderProvider>()!
        .store;
  }

  @override
  bool updateShouldNotify(covariant MangaPageLoaderProvider oldWidget) {
    return store != oldWidget.store;
  }
}

class MangaPageLoader extends StatefulWidget {
  final WidgetBuilder builder;
  final bool loaded;
  final WidgetBuilder emptyBuilder;

  const MangaPageLoader({
    required super.key,
    required this.builder,
    required this.loaded,
    required this.emptyBuilder,
  });

  @override
  State<MangaPageLoader> createState() => _MangaPageLoaderState();
}

class _MangaPageLoaderState extends State<MangaPageLoader> {
  @override
  Widget build(BuildContext context) {
    final store = MangaPageLoaderProvider.of(context);
    final key = widget.key!;
    if (widget.loaded) {
      final storedWidget = store.retrieve(key);
      if (storedWidget != null) {
        return storedWidget;
      }
      final newWidget = widget.builder(context);
      store.save(key, newWidget);
      return newWidget;
    } else {
      return widget.emptyBuilder(context);
    }
  }
}

class MangaPageLoaderStore {
  Map<Key, Widget> _pageCache = {};

  Widget? retrieve(Key key) =>
      _pageCache.containsKey(key) ? _pageCache[key] : null;

  void save(Key key, Widget widget) => _pageCache[key] = widget;
}
