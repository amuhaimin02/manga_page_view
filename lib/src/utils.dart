import 'package:flutter/cupertino.dart';

extension AxisDirectionExtension on AxisDirection {
  Axis get axis => this == AxisDirection.up || this == AxisDirection.down
      ? Axis.vertical
      : Axis.horizontal;
  bool get isReverse => this == AxisDirection.up || this == AxisDirection.left;

  bool get isVertical => axis == Axis.vertical;

  bool get isHorizontal => axis == Axis.horizontal;
}
