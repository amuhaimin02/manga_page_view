import 'package:flutter/gestures.dart';

/// Extra utilities for gesture-related handling
class GestureUtils {
  static bool isPrimaryPointer(PointerEvent event) {
    return isPrimaryTouch(event) || isLeftClicking(event);
  }

  static bool isPrimaryTouch(PointerEvent event) {
    // TODO: Checking event.device works on other platform other than iOS. Why??
    return event.kind == PointerDeviceKind.touch;
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
