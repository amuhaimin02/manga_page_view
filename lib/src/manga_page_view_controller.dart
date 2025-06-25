import 'dart:async';

import 'package:flutter/animation.dart';

import '../manga_page_view.dart';

/// A controller for [MangaPageView].
///
/// This controller allows you to manipulate its scroll position, zoom and other controls
class MangaPageViewController {
  /// Creates the controller for [MangaPageView].
  MangaPageViewController();

  final _intents = StreamController<ControllerChangeIntent>.broadcast();

  Stream<ControllerChangeIntent> get intents => _intents.stream;

  /// Disposes the controller.
  ///
  /// This method should be called when the controller is no longer needed.
  /// It releases the underlying resource it created.
  void dispose() {
    _intents.close();
  }

  /// Moves the controlled [MangaPageView] to the given page.
  ///
  /// Specify the [index] of the page to move to.
  /// Optionally, you may provide a [duration] and a [curve] to animate the movement.
  /// Having a [duration] of [Duration.zero] effectively disables the animation entirely.
  void moveToPage(
    int index, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(PageChangeIntent(index, duration, curve));
  }

  /// Moves the controlled [MangaPageView] to the given progress.
  ///
  /// Specify the [progress] of the page to move to.
  /// The range of the [progress[ value should be between 0.0 to 1.0, inclusive, corresponding
  /// to start and end of the page view.
  ///
  /// This method is usable on both [MangaPageViewMode.continuous] and [MangaPageViewMode.paged] mode.
  /// On the paged mode, the progress will behave similar to [moveToPage] where the [progress] value will be quantized instead.
  ///
  /// Optionally, you may provide a [duration] and a [curve] to animate the movement.
  /// Having a [duration] of [Duration.zero] effectively disables the animation entirely.
  void moveToProgress(
    double progress, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(ProgressChangeIntent(progress, duration, curve));
  }

  /// Zoom the controlled [MangaPageView] to the given zoom level.
  ///
  /// Optionally, you may provide a [duration] and a [curve] to animate the movement.
  /// Having a [duration] of [Duration.zero] effectively disables the animation entirely.
  void zoomTo(
    double zoomLevel, {
    Duration duration = Duration.zero,
    Curve curve = Curves.easeInOut,
  }) {
    _intents.add(ZoomChangeIntent(zoomLevel, duration, curve));
  }

  /// Moves the controlled [MangaPageView] by the given scroll delta.
  ///
  /// [delta] value corresponds to the number of pixels to move.
  /// Positive value moves the view forward and negative value moves the view backward,
  /// depending on the set direction on the page view.
  ///
  /// Optionally, you may provide a [duration] and a [curve] to animate the movement.
  /// Having a [duration] of [Duration.zero] effectively disables the animation entirely.
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
