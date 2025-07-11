// ignore_for_file: unused_element

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manga_page_view/manga_page_view.dart';

void main() {
  runApp(const MangaPageViewExampleApp());
}

class MangaPageViewExampleApp extends StatelessWidget {
  const MangaPageViewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Page View Example',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: MangaPageViewExampleScreen(),
    );
  }
}

class MangaPageViewExampleScreen extends StatefulWidget {
  const MangaPageViewExampleScreen({super.key});

  @override
  State<MangaPageViewExampleScreen> createState() =>
      _MangaPageViewExampleScreenState();
}

class _MangaPageViewExampleScreenState
    extends State<MangaPageViewExampleScreen> {
  late MangaPageViewDirection _scrollDirection;
  MangaPageViewMode _mode = MangaPageViewMode.continuous;
  bool _overshoot = true;
  MangaPageViewGravity _scrollGravity = MangaPageViewGravity.center;

  late final _controller = MangaPageViewController();

  final _currentPage = ValueNotifier(0);
  final _currentZoomLevel = ValueNotifier(1.0);
  final _totalPages = 40;
  final _currentProgress = ValueNotifier(0.0);

  // For KeyboardListener
  final _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollDirection = MangaPageViewDirection.down;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          _controller.panBy(Offset(0, -20));
        case LogicalKeyboardKey.arrowDown:
          _controller.panBy(Offset(0, 20));
        case LogicalKeyboardKey.arrowLeft:
          _controller.panBy(Offset(-20, 0));
        case LogicalKeyboardKey.arrowRight:
          _controller.panBy(Offset(20, 0));
        case LogicalKeyboardKey.pageDown:
          _controller.moveToPage(_currentPage.value + 1);
        case LogicalKeyboardKey.pageUp:
          _controller.moveToPage(_currentPage.value - 1);
        default:
        // Other key pressed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [_buildPageView(context), _buildDebugPanel(context)],
      ),
    );
  }

  Widget _buildPageView(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _onKeyEvent,
      child: MangaPageView(
        mode: _mode,
        direction: _scrollDirection,
        controller: _controller,
        options: MangaPageViewOptions(
          mainAxisOverscroll: _overshoot,
          crossAxisOverscroll: _overshoot,
          maxZoomLevel: 8,
          precacheAhead: 2,
          precacheBehind: 2,
          zoomOvershoot: _overshoot,
          pageJumpGravity: _scrollGravity,
          pageSenseGravity: _scrollGravity,
          initialPageSize: Size(600, 600),
          pageWidthLimit: 1000,
          padding: EdgeInsets.all(16),
          spacing: 16,
        ),
        pageCount: _totalPages,
        pageBuilder: (context, index) {
          // TODO: Uncomment one of the lines to change the contents
          return _buildBufferedRandomSizePage(context, index);
          // return _buildChangingRandomSizePage(context, index);
          // return _buildLongPage(context, index);
          // return _buildCachedNetworkImage(context, index);
          // return _buildNetworkImage(context, index);
        },
        onPageChange: (index) {
          _currentPage.value = index;
        },
        onZoomChange: (zoomLevel) {
          _currentZoomLevel.value = zoomLevel;
        },
        onProgressChange: (progress) {
          _currentProgress.value = progress;
        },
        startEdgeDragIndicatorBuilder: (context, info) =>
            _buildIndicator(context, info, false),
        endEdgeDragIndicatorBuilder: (context, info) =>
            _buildIndicator(context, info, true),
        onStartEdgeDrag: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Going to previous chapter')));
        },
        onEndEdgeDrag: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Going to next chapter')));
        },
      ),
    );
  }

  Widget _buildLongPage(BuildContext context, int index) {
    // Use predefined random seed for consistency
    return RandomPage(
      label: 'Page #${index + 1}',
      color: Color(0xFF000000 | Random(index).nextInt(0xFFFFFF)),
      width: 500,
      height: 2000,
    );
  }

  Widget _buildBufferedRandomSizePage(BuildContext context, int index) {
    // Simulated buffering
    return FutureBuilder(
      future: Future.delayed(
        Duration(milliseconds: Random(index).nextInt(1000) + 1000),
      ),
      builder: (context, snapshot) {
        final random = Random(index);
        if (snapshot.connectionState == ConnectionState.done) {
          // Use predefined random seed for consistency
          return RandomPage(
            label: 'Page #${index + 1}',
            color: Color(0xFF000000 | random.nextInt(0xFFFFFF)),
            width: random.nextInt(750) + 250,
            height: random.nextInt(750) + 250,
          );
        } else {
          return Container(
            width: 300,
            height: 300,
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  Widget _buildChangingRandomSizePage(BuildContext context, int index) {
    final random = Random();
    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        // Size changes are slowly transitioning
        return AnimatedSize(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: RandomPage(
            label: 'Page #${index + 1}',
            color: Color(0xFF000000 | random.nextInt(0xFFFFFF)),
            width: random.nextInt(750) + 250,
            height: random.nextInt(750) + 250,
          ),
        );
      },
    );
  }

  Widget _buildNetworkImage(BuildContext context, int index) {
    Widget loadingSpinner([double? progress]) {
      return Container(
        width: 600,
        height: 600,
        alignment: Alignment.center,
        child: CircularProgressIndicator(value: progress),
      );
    }

    return Image.network(
      'https://picsum.photos/850/1200?c=$index',
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        } else {
          return loadingSpinner();
        }
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child; // image is fully loaded
        }

        return loadingSpinner(
          loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                    (loadingProgress.expectedTotalBytes ?? 1)
              : null,
        );
      },
    );
  }

  Widget _buildCachedNetworkImage(BuildContext context, int index) {
    return CachedNetworkImage(
      fit: BoxFit.contain,
      imageUrl: 'https://picsum.photos/850/1200?c=$index',
      placeholder: (context, url) => Container(
        margin: EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        margin: EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Icon(Icons.error),
      ),
    );
  }

  Widget _buildIndicator(
    BuildContext context,
    MangaPageViewEdgeGestureInfo info,
    bool isNext,
  ) {
    return Center(
      child: AnimatedOpacity(
        opacity: info.progress,
        duration: Duration.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              decoration: ShapeDecoration(
                shape: CircleBorder(),
                color: info.isTriggered ? Colors.red : Colors.transparent,
              ),
              padding: EdgeInsets.all(8),
              child: Icon(
                switch (info.edge) {
                  MangaPageViewEdge.top => Icons.arrow_upward,
                  MangaPageViewEdge.bottom => Icons.arrow_downward,
                  MangaPageViewEdge.left => Icons.arrow_back,
                  MangaPageViewEdge.right => Icons.arrow_forward,
                },
                color: info.isTriggered ? Colors.black : Colors.white,
                size: 48,
              ),
            ),
            Text(isNext ? "Next chapter" : "Prev chapter"),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        color: Colors.black54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: _currentPage,
              builder: (context, currentPage, child) {
                return Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${currentPage + 1} / $_totalPages',
                        textAlign: TextAlign.end,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: currentPage.toDouble(),
                        max: _totalPages - 1,
                        min: 0,
                        divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                        label: '${currentPage + 1}',
                        onChanged: (value) {
                          _controller.moveToPage(value.toInt());
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _currentProgress,
              builder: (context, progress, child) {
                return Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${(progress * 100).toStringAsFixed(1)} %',
                        textAlign: TextAlign.end,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: progress,
                        onChanged: (value) {
                          _controller.moveToProgress(value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _currentZoomLevel,
              builder: (context, currentZoomLevel, child) {
                return Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 30.0, right: 4.0),
                      child: Icon(Icons.zoom_in),
                    ),
                    Expanded(
                      child: Slider(
                        value: currentZoomLevel,
                        min: 0.5,
                        max: 8.0,
                        label: currentZoomLevel.toStringAsFixed(1),
                        onChanged: (value) {
                          _controller.zoomTo(value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            Wrap(
              spacing: 16,
              children: [
                Row(
                  spacing: 16,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: () {
                        _controller.moveToPage(
                          max(0, _currentPage.value - 1),
                          duration: Duration(milliseconds: 300),
                        );
                      },
                      icon: Icon(Icons.skip_previous),
                    ),

                    IconButton(
                      tooltip: 'Scroll backward',
                      onPressed: () {
                        _controller.scrollBy(
                          -60,
                          duration: Duration(milliseconds: 300),
                        );
                      },
                      icon: Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Scroll forward',
                      onPressed: () {
                        _controller.scrollBy(
                          60,
                          duration: Duration(milliseconds: 300),
                        );
                      },
                      icon: Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: () {
                        _controller.moveToPage(
                          min(_totalPages - 1, _currentPage.value + 1),
                          duration: Duration(milliseconds: 300),
                        );
                      },
                      icon: Icon(Icons.skip_next),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    // Toggle view mode
                    IconButton(
                      tooltip: 'Toggle view mode (paged/continuous)',
                      onPressed: () {
                        setState(() {
                          _mode = switch (_mode) {
                            MangaPageViewMode.paged =>
                              MangaPageViewMode.continuous,
                            MangaPageViewMode.continuous =>
                              MangaPageViewMode.paged,
                          };
                        });
                      },
                      icon: Icon(
                        _mode == MangaPageViewMode.paged
                            ? Icons.aod
                            : Icons.import_contacts,
                      ),
                    ),
                    // Toggle scroll direction
                    IconButton(
                      tooltip: 'Scroll direction',
                      onPressed: () {
                        setState(() {
                          _scrollDirection = switch (_scrollDirection) {
                            MangaPageViewDirection.right =>
                              MangaPageViewDirection.down,
                            MangaPageViewDirection.down =>
                              MangaPageViewDirection.left,
                            MangaPageViewDirection.left =>
                              MangaPageViewDirection.up,
                            MangaPageViewDirection.up =>
                              MangaPageViewDirection.right,
                          };
                        });
                      },
                      icon: Icon(() {
                        return switch (_scrollDirection) {
                          MangaPageViewDirection.right => Icons.swipe_right_alt,
                          MangaPageViewDirection.down => Icons.swipe_down_alt,
                          MangaPageViewDirection.left => Icons.swipe_left_alt,
                          MangaPageViewDirection.up => Icons.swipe_up_alt,
                        };
                      }()),
                    ),
                    IconButton(
                      tooltip: 'Toggle overshoot/constrained',
                      onPressed: () {
                        setState(() {
                          _overshoot = !_overshoot;
                        });
                      },
                      icon: Icon(
                        _overshoot ? Icons.swipe_vertical : Icons.crop_free,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Page detection/jump gravity',
                      onPressed: () {
                        setState(() {
                          _scrollGravity = switch (_scrollGravity) {
                            MangaPageViewGravity.start =>
                              MangaPageViewGravity.center,
                            MangaPageViewGravity.center =>
                              MangaPageViewGravity.end,
                            MangaPageViewGravity.end =>
                              MangaPageViewGravity.start,
                          };
                        });
                      },
                      icon: Icon(() {
                        return switch (_scrollGravity) {
                          MangaPageViewGravity.start =>
                            Icons.align_vertical_top,
                          MangaPageViewGravity.center =>
                            Icons.align_vertical_center,
                          MangaPageViewGravity.end =>
                            Icons.align_vertical_bottom,
                        };
                      }()),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RandomPage extends StatelessWidget {
  const RandomPage({
    super.key,
    required this.label,
    required this.color,
    required this.width,
    required this.height,
  });

  final String label;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Color.lerp(color, Colors.black, 0.2)!,
            width: 16.0,
          ),
        ),
        width: width.toDouble(),
        height: height.toDouble(),
        child: Container(
          color: color,
          child: CustomPaint(
            painter: CheckerboardPainter(
              squareSize: 100,
              color1: Color.lerp(color, Colors.white, 0.2)!,
              color2: color,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(color: textColor),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${width.round()}x${height.round()}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckerboardPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  CheckerboardPainter({
    required this.squareSize,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();

    int rows = (size.height / squareSize).ceil();
    int cols = (size.width / squareSize).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        bool isEven = (row + col) % 2 == 0;
        paint.color = isEven ? color1 : color2;

        double x = col * squareSize;
        double y = row * squareSize;

        // Prevent overflow by clamping width/height at edges
        double width = (x + squareSize > size.width)
            ? size.width - x
            : squareSize;
        double height = (y + squareSize > size.height)
            ? size.height - y
            : squareSize;

        canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
