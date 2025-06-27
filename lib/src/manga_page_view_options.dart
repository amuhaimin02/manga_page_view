import 'package:flutter/widgets.dart';

/// Options for configuring the behavior of a [MangaPageView].
class MangaPageViewOptions {
  /// Creates a set of options for a [MangaPageView].
  /// All parameters are optional and have default values.
  const MangaPageViewOptions({
    this.minZoomLevel = 0.5,
    this.maxZoomLevel = 4.0,
    this.initialZoomLevel = 1.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.padding = EdgeInsets.zero,
    this.spacing = 0.0,
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
    this.edgeIndicatorContainerSize = 200.0,
  })  : assert(minZoomLevel > 0),
        assert(maxZoomLevel > 0),
        assert(maxZoomLevel > minZoomLevel),
        assert(initialZoomLevel >= minZoomLevel),
        assert(initialZoomLevel <= maxZoomLevel),
        assert(spacing >= 0),
        assert(precacheAhead >= 0),
        assert(precacheBehind >= 0),
        assert(pageWidthLimit == null || pageWidthLimit > 0),
        assert(pageHeightLimit == null || pageHeightLimit > 0),
        assert(edgeIndicatorContainerSize > 0);

  /// The minimum allowed zoom level.
  ///
  /// The value should be greater than zero and not exceed [maxZoomLevel].
  final double minZoomLevel;

  /// The maximum allowed zoom level.
  ///
  /// The value should be greater than [minZoomLevel] and not exceed [minZoomLevel].
  final double maxZoomLevel;

  /// The initial zoom level when the view is first displayed.
  ///
  /// Should be between [minZoomLevel] and [maxZoomLevel].
  final double initialZoomLevel;

  /// A list of zoom levels that can be quickly cycled when double tapping to zoom.
  /// Values are sorted internally, and those that fall outside min/max zoom bounds will be ignored.
  final List<double> presetZoomLevels;

  /// The padding around the content of the [MangaPageView].
  ///
  /// In case of [MangaPageViewMode.continuous] mode, paddings are applied on the entire page strip.
  /// On [MangaPageViewMode.paged], paddings are applied on individual page.
  ///
  /// Note that the value will be affected by zoom levels.
  /// Zooming in increases the effective padding and vice versa.
  /// Values of pixels are based on 1.0 zoom level.
  final EdgeInsets padding;

  /// The spacing between pages in the main axis, in pixels.
  ///
  /// Note that the value will be affected by zoom levels.
  /// Zooming in increases the effective padding and vice versa.
  /// Values of pixels are based on 1.0 zoom level.
  ///
  /// Only applicable on [MangaPageViewMode.continuous] mode. No effect on [MangaPageViewMode.paged] mode.
  final double spacing;

  /// The initial size assumed for pages before they are loaded.
  ///
  /// This is used for empty placeholder sizing and for size estimation when scrolling through pages.
  ///
  /// Tip: Be sure to provide a suitable value based on the expected viewport size and your pages' content.
  /// Setting too low or too high might cause page jumping to not load properly.
  /// Default of 512x512 pixels can serve as a good starting point.
  final Size initialPageSize;

  /// Whether overscrolling is allowed in the main axis.
  ///
  /// If enabled, scrolling follows natural movement of touch or cursor and positions will settle slowly on lift.
  /// If disabled, scrolling will always constrained to the scrollable boundaries.
  final bool mainAxisOverscroll;

  /// Whether overscrolling is allowed in the cross axis.
  ///
  /// If enabled, scrolling follows natural movement of touch or cursor and positions will settle slowly on lift.
  /// If disabled, scrolling will always constrained to the scrollable boundaries.
  final bool crossAxisOverscroll;

  /// Whether zooming beyond the min/max zoom levels temporarily is allowed (with a snap back).
  final bool zoomOvershoot;

  /// The number of pages to precache ahead of the current viewport in the reading direction.
  ///
  /// For example, setting this value of 2 will cause the next two pages to be preloaded.
  final int precacheAhead;

  /// The number of pages to precache behind the current viewport in the reading direction.
  ///
  /// For example, setting this value of 2 will cause the previous two pages to be preloaded.
  /// Useful when user jumps to the page region that doesn't load yet.
  final int precacheBehind;

  /// An optional limit for the width of a page. If set, pages will be scaled down to fit this width.
  final double? pageWidthLimit;

  /// An optional limit for the height of a page. If set, pages will be scaled down to fit this height.
  final double? pageHeightLimit;

  /// Determines how the "current" page is sensed when scrolling.
  ///
  /// Page position will be incremented depending on the value set as follows.
  /// - On [MangaPageViewGravity.start]: when the leading edge of the page approaches the start edge of the viewport.
  /// - On [MangaPageViewGravity.center]: when the leading edge of the page approaches the center of the viewport.
  /// - On [MangaPageViewGravity.end]: when the trailing edge of the page approaches the end edge of the viewport.
  final MangaPageViewGravity pageSenseGravity;

  /// Determines where the page should snaps to when jumping to a specific page.
  ///
  /// Page positon will be placed depending on the value set as follows.
  /// - On [MangaPageViewGravity.start]: leading edge of the page snaps to the start edge of the viewport.
  /// - On [MangaPageViewGravity.center], leading edge of the page snaps to the center of the viewport.
  /// - On [MangaPageViewGravity.end], trailing edge of the page snaps to the end edge of the viewport.
  final MangaPageViewGravity pageJumpGravity;

  /// Whether pinch-to-zoom gestures should zoom towards the focal point of the gesture.
  ///
  /// If disabled, zooming will occur towards the center of the viewport.
  final bool zoomOnFocalPoint;

  /// The duration of the fade-in animation for initially loaded pages.
  final Duration initialFadeInDuration;

  /// The curve used for the initial page fade-in animation.
  final Curve initialFadeInCurve;

  /// The size of the container used for edge indicators (e.g., for "next chapter" gestures).
  ///
  /// Depending on the [MangaPageViewDirection] used, the value will mean:
  /// - width: for [MangaPageViewDirection.left] and [MangaPageViewDirection.right].
  /// - height: for [MangaPageViewDirection.up] and [MangaPageViewDirection.down].
  ///
  /// This value also determines how many pixels user should drag to trigger the gestures.
  final double edgeIndicatorContainerSize;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MangaPageViewOptions &&
        other.minZoomLevel == minZoomLevel &&
        other.maxZoomLevel == maxZoomLevel &&
        other.initialZoomLevel == initialZoomLevel &&
        other.presetZoomLevels == presetZoomLevels &&
        other.padding == padding &&
        other.spacing == spacing &&
        other.initialPageSize == initialPageSize &&
        other.mainAxisOverscroll == mainAxisOverscroll &&
        other.crossAxisOverscroll == crossAxisOverscroll &&
        other.zoomOvershoot == zoomOvershoot &&
        other.precacheAhead == precacheAhead &&
        other.precacheBehind == precacheBehind &&
        other.pageWidthLimit == pageWidthLimit &&
        other.pageHeightLimit == pageHeightLimit &&
        other.pageSenseGravity == pageSenseGravity &&
        other.pageJumpGravity == pageJumpGravity &&
        other.zoomOnFocalPoint == zoomOnFocalPoint &&
        other.initialFadeInDuration == initialFadeInDuration &&
        other.initialFadeInCurve == initialFadeInCurve &&
        other.edgeIndicatorContainerSize == edgeIndicatorContainerSize;
  }

  @override
  int get hashCode {
    return minZoomLevel.hashCode ^
        maxZoomLevel.hashCode ^
        initialZoomLevel.hashCode ^
        presetZoomLevels.hashCode ^
        padding.hashCode ^
        spacing.hashCode ^
        initialPageSize.hashCode ^
        mainAxisOverscroll.hashCode ^
        crossAxisOverscroll.hashCode ^
        zoomOvershoot.hashCode ^
        precacheAhead.hashCode ^
        precacheBehind.hashCode ^
        pageWidthLimit.hashCode ^
        pageHeightLimit.hashCode ^
        pageSenseGravity.hashCode ^
        pageJumpGravity.hashCode ^
        zoomOnFocalPoint.hashCode ^
        initialFadeInDuration.hashCode ^
        initialFadeInCurve.hashCode ^
        edgeIndicatorContainerSize.hashCode;
  }
}

/// Defines the display mode of the [MangaPageView].
enum MangaPageViewMode {
  /// Pages are laid out continuously in the reading direction as a long strip.
  /// Orientation depends on the direction set.
  continuous,

  /// Pages are displayed one at a time, with gestures to navigate between them.
  paged,
}

/// Defines the gravity or alignment point within the viewport.
enum MangaPageViewGravity {
  /// Aligns to the start of the viewport in the reading direction.
  start,

  /// Aligns to the center of the viewport.
  center,

  /// Aligns to the end of the viewport in the reading direction.
  end;

  /// Selects a value based on the current gravity.
  ///
  /// This is a utility method to avoid switch statements when you need to
  /// choose a value based on the gravity.
  T select<T>({required T start, required T center, required T end}) {
    return switch (this) {
      MangaPageViewGravity.start => start,
      MangaPageViewGravity.center => center,
      MangaPageViewGravity.end => end,
    };
  }
}

/// Defines the reading direction for the [MangaPageView].
enum MangaPageViewDirection {
  /// Pages are laid out from bottom to top.
  up,

  /// Pages are laid out from top to bottom.
  down,

  /// Pages are laid out from right to left.
  left,

  /// Pages are laid out from left to right.
  right;

  Axis get axis {
    return switch (this) {
      MangaPageViewDirection.up => Axis.vertical,
      MangaPageViewDirection.down => Axis.vertical,
      MangaPageViewDirection.left => Axis.horizontal,
      MangaPageViewDirection.right => Axis.horizontal,
    };
  }

  /// Returns `true` if the reading direction is reversed (e.g., right-to-left or bottom-to-top).
  bool get isReverse =>
      this == MangaPageViewDirection.left || this == MangaPageViewDirection.up;

  /// Returns `true` if the reading direction is vertical.
  bool get isVertical => axis == Axis.vertical;

  /// Returns `true` if the reading direction is horizontal.
  bool get isHorizontal => axis == Axis.horizontal;
}

/// Represents an edge of the [MangaPageView].
enum MangaPageViewEdge {
  /// The top edge.
  top,

  /// The bottom edge.
  bottom,

  /// The left edge.
  left,

  /// The right edge.
  right;

  /// The axis corresponding to this edge.
  Axis get axis {
    return switch (this) {
      MangaPageViewEdge.top => Axis.vertical,
      MangaPageViewEdge.bottom => Axis.vertical,
      MangaPageViewEdge.left => Axis.horizontal,
      MangaPageViewEdge.right => Axis.horizontal,
    };
  }

  /// Returns `true` if this edge is considered "reversed" in the context of reading direction.
  /// For example, the right edge is reversed for left-to-right reading.
  bool get isReverse =>
      this == MangaPageViewEdge.right || this == MangaPageViewEdge.bottom;

  /// Returns `true` if this edge is vertical.
  bool get isVertical => axis == Axis.vertical;

  /// Returns `true` if this edge is horizontal.
  bool get isHorizontal => axis == Axis.horizontal;
}

/// Information about a gesture occurring at the edge of the [MangaPageView].
class MangaPageViewEdgeGestureInfo {
  /// Creates information about an edge gesture.
  MangaPageViewEdgeGestureInfo({
    required this.edge,
    required this.progress,
    required this.isTriggered,
  });

  /// The specific edge where the gesture is happening.
  final MangaPageViewEdge edge;

  /// The progress of the gesture, typically a value between 0.0 and 1.0.
  /// 0.0 usually means the gesture has just started at the edge, and 1.0
  /// means it has reached a threshold to be considered "triggered".
  final double progress;

  /// Whether the gesture has reached a state to be considered "triggered".
  final bool isTriggered;
}
