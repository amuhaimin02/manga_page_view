import 'package:flutter/gestures.dart';

class DoubleTapDetector {
  static const _durationThreshold = kDoubleTapTimeout;
  static const _distanceThreshold = kDoubleTapSlop;

  Duration? _firstTapTimestamp;
  Offset? _firstTapPosition;
  bool _isDoubleTapActive = false;

  void registerTap(Duration timestamp, Offset position) {
    if (_firstTapTimestamp != null) {
      // Second tap
      final timeDiff = timestamp - _firstTapTimestamp!;
      final distance = (position - _firstTapPosition!).distance;

      final validDoubleTap =
          timeDiff <= _durationThreshold && distance <= _distanceThreshold;

      if (validDoubleTap) {
        _isDoubleTapActive = true;
      } else {
        _isDoubleTapActive = false;
        // Too long to be a double tap. Consider this the new first tap.
        _firstTapTimestamp = timestamp;
        _firstTapPosition = position;
      }
    } else {
      // First tap
      _isDoubleTapActive = false;
      _firstTapTimestamp = timestamp;
      _firstTapPosition = position;
    }
  }

  bool isActive(Duration timestamp) {
    return _isDoubleTapActive &&
        timestamp - _firstTapTimestamp! <= _durationThreshold;
  }

  void reset() {
    _firstTapTimestamp = null;
    _firstTapPosition = null;
    _isDoubleTapActive = false;
  }

  /// Returns true if a second tap is expected within the threshold.
  bool isAwaitingSecondTap(Duration timestamp, Offset position) {
    return _firstTapTimestamp != null &&
        timestamp - _firstTapTimestamp! <= _durationThreshold &&
        (position - _firstTapPosition!).distance <= _distanceThreshold;
  }
}
