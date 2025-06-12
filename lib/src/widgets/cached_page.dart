import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

@internal
class CachedPage extends StatefulWidget {
  const CachedPage({
    super.key,
    required this.builder,
    required this.visible,
    required this.initialSize,
  });

  final bool visible;
  final WidgetBuilder builder;
  final Size initialSize;

  @override
  State<CachedPage> createState() => _CachedPageState();
}

class _CachedPageState extends State<CachedPage> {
  Widget? child;

  @override
  Widget build(BuildContext context) {
    if (widget.visible) {
      if (child == null) {
        child = widget.builder(context);
      }
      return child!;
    } else {
      return SizedBox.fromSize(size: widget.initialSize);
    }
  }
}
