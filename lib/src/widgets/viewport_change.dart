import 'package:flutter/widgets.dart';

class ViewportChangeListener extends StatefulWidget {
  const ViewportChangeListener({super.key, required this.child});

  final Widget child;

  @override
  State<ViewportChangeListener> createState() => _ViewportChangeListenerState();
}

class _ViewportChangeListenerState extends State<ViewportChangeListener> {
  final ValueNotifier<Size> _viewportSize = ValueNotifier(Size.zero);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize.value = constraints.biggest;
        return ViewportSizeProvider(
          viewportSize: _viewportSize,
          child: widget.child,
        );
      },
    );
  }
}

class ViewportSizeProvider extends InheritedWidget {
  const ViewportSizeProvider({
    super.key,
    required super.child,
    required this.viewportSize,
  });

  final ValueNotifier<Size> viewportSize;

  static ValueNotifier<Size> of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ViewportSizeProvider>()!
        .viewportSize;
  }

  @override
  bool updateShouldNotify(ViewportSizeProvider oldWidget) {
    return viewportSize != oldWidget.viewportSize;
  }
}
