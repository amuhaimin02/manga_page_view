import 'package:flutter/material.dart';

class MangaPageViewOptions {
  final MangaPageViewMode mode;
  final double minZoomLevel;
  final double maxZoomLevel;
  final double initialZoomLevel;
  final List<double> presetZoomLevels;
  final double spacing;
  final PageViewDirection direction;
  final Size initialPageSize;
  final Size maxPageSize;
  final bool mainAxisOverscroll;
  final bool crossAxisOverscroll;
  final bool zoomOvershoot;
  final int precacheOverhead;
  final PageViewGravity pageSenseGravity;
  final PageViewGravity pageJumpGravity;
  final bool zoomOnFocalPoint;

  const MangaPageViewOptions({
    this.mode = MangaPageViewMode.continuous,
    this.minZoomLevel = 0.5,
    this.maxZoomLevel = 4.0,
    this.initialZoomLevel = 1.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.spacing = 0.0,
    this.direction = PageViewDirection.down,
    this.initialPageSize = const Size(512, 512),
    this.maxPageSize = const Size(4096, 4096),
    this.mainAxisOverscroll = true,
    this.crossAxisOverscroll = true,
    this.zoomOvershoot = true,
    this.precacheOverhead = 0,
    this.pageSenseGravity = PageViewGravity.center,
    this.pageJumpGravity = PageViewGravity.start,
    this.zoomOnFocalPoint = true,
  });
}

enum MangaPageViewMode { screen, continuous }

enum PageViewDirection {
  up,
  down,
  left,
  right;

  bool get isVertical => this == up || this == down;
  bool get isHorizontal => this == left || this == right;
  bool get isReverse => this == up || this == left;
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
