import 'package:flutter/material.dart';

class MangaPageViewOptions {
  final double minZoomLevel;
  final double maxZoomLevel;
  final double initialZoomLevel;
  final List<double> presetZoomLevels;
  final PageViewDirection direction;
  final Size initialPageSize;
  final Size maxPageSize;
  final bool mainAxisOverscroll;
  final bool crossAxisOverscroll;
  final int precacheOverhead;

  const MangaPageViewOptions({
    this.minZoomLevel = 0.25,
    this.maxZoomLevel = 4.0,
    this.initialZoomLevel = 1.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.direction = PageViewDirection.down,
    this.initialPageSize = const Size(300, 300),
    this.maxPageSize = const Size(2400, 1600),
    this.mainAxisOverscroll = true,
    this.crossAxisOverscroll = true,
    this.precacheOverhead = 3,
  });
}

enum PageViewDirection {
  up,
  down,
  left,
  right;

  bool get isVertical => this == up || this == down;
  bool get isHorizontal => this == left || this == right;
  bool get isReverse => this == up || this == left;
}
