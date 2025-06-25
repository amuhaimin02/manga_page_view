import 'package:flutter/gestures.dart';
import 'package:meta/meta.dart';

/// Extra utilities for gesture-related handling
@internal
class GestureUtils {
  static bool isPrimaryPointer(PointerEvent event) {
    return isPrimaryTouch(event) || isLeftClicking(event);
  }

  static bool isPrimaryTouch(PointerEvent event) {
    return event.kind == PointerDeviceKind.touch && event.device <= 0;
  }

  static bool isLeftClicking(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event is PointerUpEvent || event is PointerCancelEvent)) {
      // "UP" event doesn't have any buttons pressed
      return true;
    }
    return event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryMouseButton;
  }
}
