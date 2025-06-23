import 'package:flutter/widgets.dart';
import 'package:manga_page_view/src/widgets/interactive_panel.dart';
import 'package:manga_page_view/src/widgets/page_carousel.dart';

class PageEndGestureWrapper extends StatefulWidget {
  const PageEndGestureWrapper({
    super.key,
    required this.child,
    required this.detectionAxis,
  });

  final Axis detectionAxis;
  final Widget child;

  @override
  State<PageEndGestureWrapper> createState() => _PageEndGestureWrapperState();
}

class _PageEndGestureWrapperState extends State<PageEndGestureWrapper> {
  bool _canTrigger = false;
  AxisDirection? _moveDirection;

  void _handleTouch() {}

  void _handleSwipe(Offset delta) {}

  void _handleLift() {
    _canTrigger = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.device != 0) return;
        _handleTouch();
      },
      onPointerMove: (event) {
        if (event.device != 0) return;
        _handleSwipe(event.localDelta);
      },
      onPointerUp: (event) {
        if (event.device != 0) return;
        _handleLift();
      },
      onPointerCancel: (event) {
        if (event.device != 0) return;
        _handleLift();
      },
      onPointerPanZoomStart: (event) {
        _handleTouch();
      },
      onPointerPanZoomUpdate: (event) {
        _handleSwipe(event.localDelta);
      },
      onPointerPanZoomEnd: (event) {
        _handleLift();
      },
      child: NotificationListener(
        onNotification: (event) {
          if (event is InteractivePanelReachingEdgeNotification ||
              event is PageCarouselReachingEdgeNotification) {
            _canTrigger = true;
            return true;
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
