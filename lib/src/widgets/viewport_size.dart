import 'package:flutter/widgets.dart';

class ViewportSize extends StatefulWidget {
  const ViewportSize({super.key, required this.child});
  final Widget child;

  @override
  State<ViewportSize> createState() => _ViewportSizeState();

  static ValueNotifier<Size> of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ViewportSizeInheritedNotifier>()!
      .notifier!;
}

class _ViewportSizeState extends State<ViewportSize> {
  final _notifier = ValueNotifier<Size>(Size.zero);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final newSize = constraints.biggest;
        if (_notifier.value != newSize) _notifier.value = newSize;
        return _ViewportSizeInheritedNotifier(
          notifier: _notifier,
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }
}

class _ViewportSizeInheritedNotifier
    extends InheritedNotifier<ValueNotifier<Size>> {
  const _ViewportSizeInheritedNotifier({
    required super.notifier,
    required super.child,
  });
}
