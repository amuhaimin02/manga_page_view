import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

bool isPrimaryPointer(PointerEvent event) {
  return isPrimaryTouch(event) || isLeftClicking(event);
}

bool isPrimaryTouch(PointerEvent event) {
  return event.kind == PointerDeviceKind.touch && event.device <= 0;
}

bool isLeftClicking(PointerEvent event) {
  if (kIsWeb &&
      event.kind == PointerDeviceKind.mouse &&
      (event is PointerUpEvent || event is PointerCancelEvent)) {
    return true;
  }
  return event.kind == PointerDeviceKind.mouse &&
      event.buttons == kPrimaryMouseButton;
}
