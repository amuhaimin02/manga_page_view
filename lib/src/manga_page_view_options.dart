import 'package:flutter/material.dart';

class MangaPageViewOptions {
  final double minZoomLevel;
  final double maxZoomLevel;
  final List<double> presetZoomLevels;
  final Axis scrollDirection;
  final bool reverseItemOrder;

  const MangaPageViewOptions({
    this.minZoomLevel = 0.25,
    this.maxZoomLevel = 4.0,
    this.presetZoomLevels = const [1.0, 2.0, 4.0],
    this.scrollDirection = Axis.vertical,
    this.reverseItemOrder = false,
  });
}
