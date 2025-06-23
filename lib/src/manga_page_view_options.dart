import 'package:flutter/widgets.dart';

class MangaPageViewOptions {
  final MangaPageViewMode mode;
  final double minZoomLevel;
  final double maxZoomLevel;
  final double initialZoomLevel;
  final List<double> presetZoomLevels;
  final EdgeInsets padding;
  final double spacing;
  final PageViewDirection direction;
  final Size initialPageSize;
  final bool mainAxisOverscroll;
  final bool crossAxisOverscroll;
  final bool zoomOvershoot;
  final int precacheAhead;
  final int precacheBehind;
  final double? pageWidthLimit;
  final double? pageHeightLimit;
  final PageViewGravity pageSenseGravity;
  final PageViewGravity pageJumpGravity;
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
    this.direction = PageViewDirection.down,
    this.initialPageSize = const Size(512, 512),
    this.mainAxisOverscroll = true,
    this.crossAxisOverscroll = true,
    this.zoomOvershoot = true,
    this.precacheAhead = 0,
    this.precacheBehind = 0,
    this.pageWidthLimit = null,
    this.pageHeightLimit = null,
    this.pageSenseGravity = PageViewGravity.center,
    this.pageJumpGravity = PageViewGravity.start,
    this.zoomOnFocalPoint = true,
    this.initialFadeInDuration = const Duration(milliseconds: 300),
    this.initialFadeInCurve = Curves.linear,
  });
}

enum MangaPageViewMode { continuous, paged }

enum PageViewDirection {
  up,
  down,
  left,
  right;

  bool get isVertical => this == up || this == down;
  bool get isHorizontal => this == left || this == right;
  bool get isReverse => this == up || this == left;

  Axis get axis => isVertical ? Axis.vertical : Axis.horizontal;
}

enum PageViewGravity {
  start,
  center,
  end;

  T select<T>({required T start, required T center, required T end}) {
    return switch (this) {
      PageViewGravity.start => start,
      PageViewGravity.center => center,
      PageViewGravity.end => end,
    };
  }
}
