import 'dart:async';
import 'dart:ui';

class Throttler {
  final Duration interval;
  Timer? _timer;
  bool _canCall = true;

  Throttler(this.interval);

  void call(VoidCallback action) {
    if (_canCall) {
      action();
      _canCall = false;
      _timer = Timer(interval, () => _canCall = true);
    }
  }

  void cancel() {
    _timer?.cancel();
    _canCall = true;
  }

  bool get isThrottled => !_canCall;
}
