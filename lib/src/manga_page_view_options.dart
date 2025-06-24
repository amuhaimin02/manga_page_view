import 'package:flutter/widgets.dart';

class MangaPageViewOptions {
  const MangaPageViewOptions({
    this.minZoomLevel = 0.5,
    this.maxZoomLevel = 4.0,
    this.initialZoomLevel = 1.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.padding = EdgeInsets.zero,
    this.spacing = 0.0,
    this.direction = MangaPageViewDirection.down,
    this.initialPageSize = const Size(512, 512),
    this.mainAxisOverscroll = true,
    this.crossAxisOverscroll = true,
    this.zoomOvershoot = true,
    this.precacheAhead = 0,
    this.precacheBehind = 0,
    this.pageWidthLimit,
    this.pageHeightLimit,
    this.pageSenseGravity = MangaPageViewGravity.center,
    this.pageJumpGravity = MangaPageViewGravity.center,
    this.zoomOnFocalPoint = true,
    this.initialFadeInDuration = const Duration(milliseconds: 300),
    this.initialFadeInCurve = Curves.linear,
    this.edgeIndicatorContainerSize = 200,
  });
  final double minZoomLevel;
  final double maxZoomLevel;
  final double initialZoomLevel;
  final List<double> presetZoomLevels;
  final EdgeInsets padding;
  final double spacing;
  final MangaPageViewDirection direction;
  final Size initialPageSize;
  final bool mainAxisOverscroll;
  final bool crossAxisOverscroll;
  final bool zoomOvershoot;
  final int precacheAhead;
  final int precacheBehind;
  final double? pageWidthLimit;
  final double? pageHeightLimit;
  final MangaPageViewGravity pageSenseGravity;
  final MangaPageViewGravity pageJumpGravity;
  final bool zoomOnFocalPoint;
  final Duration initialFadeInDuration;
  final Curve initialFadeInCurve;
  final double edgeIndicatorContainerSize;
}

enum MangaPageViewMode { continuous, paged }

enum MangaPageViewGravity {
  start,
  center,
  end;

  T select<T>({required T start, required T center, required T end}) {
    return switch (this) {
      MangaPageViewGravity.start => start,
      MangaPageViewGravity.center => center,
      MangaPageViewGravity.end => end,
    };
  }
}

enum MangaPageViewDirection {
  up,
  down,
  left,
  right;

  Axis get axis {
    return switch (this) {
      MangaPageViewDirection.up => Axis.vertical,
      MangaPageViewDirection.down => Axis.vertical,
      MangaPageViewDirection.left => Axis.horizontal,
      MangaPageViewDirection.right => Axis.horizontal,
    };
  }

  bool get isReverse =>
      this == MangaPageViewDirection.left || this == MangaPageViewDirection.up;

  bool get isVertical => axis == Axis.vertical;
  bool get isHorizontal => axis == Axis.horizontal;
}

enum MangaPageViewEdge {
  top,
  bottom,
  left,
  right;

  Axis get axis {
    return switch (this) {
      MangaPageViewEdge.top => Axis.vertical,
      MangaPageViewEdge.bottom => Axis.vertical,
      MangaPageViewEdge.left => Axis.horizontal,
      MangaPageViewEdge.right => Axis.horizontal,
    };
  }

  bool get isReverse =>
      this == MangaPageViewEdge.right || this == MangaPageViewEdge.bottom;

  bool get isVertical => axis == Axis.vertical;
  bool get isHorizontal => axis == Axis.horizontal;
}

enum MangaPageViewEdgeGestureSide { start, end }

class MangaPageViewEdgeGestureInfo {
  MangaPageViewEdgeGestureInfo({
    required this.edge,
    required this.progress,
    required this.isTriggered,
    required this.side,
  });

  final MangaPageViewEdge edge;
  final double progress;
  final bool isTriggered;
  final MangaPageViewEdgeGestureSide side;
}
