import 'dart:async';

import 'package:flutter/animation.dart';

class MangaPageViewController {
  MangaPageViewController();

  final _intents = StreamController<ControllerChangeIntent>.broadcast();

  Stream<ControllerChangeIntent> get intents => _intents.stream;

  void dispose() {
    _intents.close();
  }

  void moveToPage(
    int index, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(PageChangeIntent(index, duration, curve));
  }

  void moveToProgress(
    double progress, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(ProgressChangeIntent(progress, duration, curve));
  }

  void zoomTo(
    double zoomLevel, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(ZoomChangeIntent(zoomLevel, duration, curve));
  }

  void scrollBy(
    double delta, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(ScrollDeltaChangeIntent(delta, duration, curve));
  }
}

sealed class ControllerChangeIntent {
  const ControllerChangeIntent();
}

class PageChangeIntent extends ControllerChangeIntent {
  const PageChangeIntent(this.index, this.duration, this.curve);
  final int index;
  final Duration duration;
  final Curve curve;
}

class ProgressChangeIntent extends ControllerChangeIntent {
  const ProgressChangeIntent(this.progress, this.duration, this.curve);
  final double progress;
  final Duration duration;
  final Curve curve;
}

class ScrollDeltaChangeIntent extends ControllerChangeIntent {
  const ScrollDeltaChangeIntent(this.delta, this.duration, this.curve);
  final double delta;
  final Duration duration;
  final Curve curve;
}

class ZoomChangeIntent extends ControllerChangeIntent {
  const ZoomChangeIntent(this.zoomLevel, this.duration, this.curve);
  final double zoomLevel;
  final Duration duration;
  final Curve curve;
}
