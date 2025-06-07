import 'package:flutter/material.dart';

class MangaPageViewOptions {
  final double minZoomLevel;
  final double maxZoomLevel;
  final Axis scrollDirection;

  const MangaPageViewOptions({
    this.minZoomLevel = 0.5,
    this.maxZoomLevel = 4.0,
    this.scrollDirection = Axis.vertical,
  });
}
