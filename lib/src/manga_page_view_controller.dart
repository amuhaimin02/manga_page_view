import 'dart:async';

class MangaPageViewController {
  MangaPageViewController();

  final _intents = StreamController<ControllerChangeIntent>.broadcast();

  Stream<ControllerChangeIntent> get intents => _intents.stream;

  void dispose() {
    _intents.close();
  }

  void jumpToPage(int index) {
    _intents.add(PageChangeIntent(index: index, animate: false));
  }

  void animateToPage(int index) {
    _intents.add(PageChangeIntent(index: index, animate: true));
  }

  void jumpToProgress(double progress) {
    _intents.add(ProgressChangeIntent(progress: progress, animate: false));
  }

  void animateToProgress(double progress) {
    _intents.add(ProgressChangeIntent(progress: progress, animate: true));
  }
}

sealed class ControllerChangeIntent {
  const ControllerChangeIntent();
}

class PageChangeIntent extends ControllerChangeIntent {
  final int index;
  final bool animate;

  const PageChangeIntent({required this.index, required this.animate});
}

class ProgressChangeIntent extends ControllerChangeIntent {
  final double progress;
  final bool animate;

  const ProgressChangeIntent({required this.progress, required this.animate});
}
