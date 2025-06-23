import 'package:flutter/widgets.dart';

class MangaPageViewOptions {
  final MangaPageViewMode mode;
  final double minZoomLevel;
  final double maxZoomLevel;
  final double initialZoomLevel;
  final List<double> presetZoomLevels;
  final EdgeInsets padding;
  final double spacing;
  final AxisDirection direction;
  final Size initialPageSize;
  final bool mainAxisOverscroll;
  final bool crossAxisOverscroll;
  final bool zoomOvershoot;
  final int precacheAhead;
  final int precacheBehind;
  final double? pageWidthLimit;
  final double? pageHeightLimit;
  final Gravity pageSenseGravity;
  final Gravity pageJumpGravity;
  final bool zoomOnFocalPoint;
  final Duration initialFadeInDuration;
  final Curve initialFadeInCurve;

  const MangaPageViewOptions({
    this.mode = MangaPageViewMode.paged,
    this.minZoomLevel = 0.5,
    this.maxZoomLevel = 4.0,
    this.initialZoomLevel = 1.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.padding = EdgeInsets.zero,
    this.spacing = 0.0,
    this.direction = AxisDirection.down,
    this.initialPageSize = const Size(512, 512),
    this.mainAxisOverscroll = true,
    this.crossAxisOverscroll = true,
    this.zoomOvershoot = true,
    this.precacheAhead = 0,
    this.precacheBehind = 0,
    this.pageWidthLimit = null,
    this.pageHeightLimit = null,
    this.pageSenseGravity = Gravity.center,
    this.pageJumpGravity = Gravity.start,
    this.zoomOnFocalPoint = true,
    this.initialFadeInDuration = const Duration(milliseconds: 300),
    this.initialFadeInCurve = Curves.linear,
  });
}

enum MangaPageViewMode { continuous, paged }

enum Gravity {
  start,
  center,
  end;

  T select<T>({required T start, required T center, required T end}) {
    return switch (this) {
      Gravity.start => start,
      Gravity.center => center,
      Gravity.end => end,
    };
  }
}
