import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:manga_page_view/manga_page_view.dart';

void main() {
  runApp(const MangaPagesExampleApp());
}

final _random = Random();

class MangaPagesExampleApp extends StatefulWidget {
  const MangaPagesExampleApp({super.key});

  @override
  State<MangaPagesExampleApp> createState() => _MangaPagesExampleAppState();
}

class _MangaPagesExampleAppState extends State<MangaPagesExampleApp> {
  late PageViewDirection _scrollDirection;
  MangaPageViewMode _mode = MangaPageViewMode.continuous;
  bool _overshoot = true;
  PageViewGravity _scrollGravity = PageViewGravity.center;

  late final _controller = MangaPageViewController();

  final _currentPage = ValueNotifier(0);
  final totalPages = 40;
  final _currentProgress = ValueNotifier<MangaPageViewScrollProgress?>(null);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollDirection =
        MediaQuery.of(context).orientation == Orientation.portrait
        ? PageViewDirection.down
        : PageViewDirection.right;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Pages Example',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            MangaPageView(
              controller: _controller,
              options: MangaPageViewOptions(
                mode: _mode,
                direction: _scrollDirection,
                mainAxisOverscroll: _overshoot,
                crossAxisOverscroll: _overshoot,
                maxZoomLevel: 10,
                precacheAhead: 2,
                precacheBehind: 2,
                zoomOvershoot: _overshoot,
                pageJumpGravity: _scrollGravity,
                pageSenseGravity: _scrollGravity,
                initialPageSize: Size(600, 600),
              ),
              pageCount: totalPages,
              pageBuilder: (context, index) {
                print('Loading page ${index + 1}');
                // return FittedBox(
                //   fit: BoxFit.contain,
                //   child: RandomPage(
                //     label: 'Page #${index + 1}',
                //     color: Color(0xFF000000 | _random.nextInt(0xFFFFFF)),
                //     // width: _random.nextInt(750) + 250,
                //     // height: _random.nextInt(750) + 250,
                //     width: 1000,
                //     height: 1600,
                //   ),
                // );
                Widget loadingSpinner([double? progress]) {
                  return Container(
                    width: 600,
                    height: 600,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(value: progress),
                  );
                }

                return Image.network(
                  'https://picsum.photos/851/1201?c=$index',
                  fit: BoxFit.contain,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
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
              },
              onPageChange: (index) {
                _currentPage.value = index;
              },
              onProgressChange: (progress) {
                // TODO: Do not use this
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _currentProgress.value = progress;
                });
              },
            ),
            _buildDebugPanel(context),
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
                        '${currentPage + 1} / $totalPages',
                        textAlign: TextAlign.end,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: currentPage.toDouble(),
                        max: totalPages - 1,
                        min: 0,
                        divisions: totalPages - 1,
                        label: '${currentPage + 1}',
                        onChanged: (value) {
                          _controller.jumpToPage(value.toInt());
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
                final fraction = progress != null ? progress.fraction : 0.0;
                return Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${(fraction * 100).toStringAsFixed(1)} %',
                        textAlign: TextAlign.end,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: fraction,
                        // max: _currentProgress?.totalPixels ?? 0,
                        onChanged: (value) {
                          _controller.jumpToFraction(value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                IconButton(
                  onPressed: () {
                    _controller.jumpToPage(max(0, _currentPage.value - 1));
                  },
                  icon: Icon(Icons.skip_previous),
                ),
                IconButton(
                  onPressed: () {
                    _controller.jumpToPage(
                      min(totalPages - 1, _currentPage.value + 1),
                    );
                  },
                  icon: Icon(Icons.skip_next),
                ),
                // Toggle view mode
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mode = switch (_mode) {
                        MangaPageViewMode.continuous =>
                          MangaPageViewMode.screen,
                        MangaPageViewMode.screen =>
                          MangaPageViewMode.continuous,
                      };
                    });
                  },
                  icon: Icon(
                    _mode == MangaPageViewMode.continuous
                        ? Icons.aod
                        : Icons.import_contacts,
                  ),
                ),
                // Toggle scroll direction
                IconButton(
                  onPressed: () {
                    setState(() {
                      _scrollDirection = switch (_scrollDirection) {
                        PageViewDirection.right => PageViewDirection.down,
                        PageViewDirection.down => PageViewDirection.left,
                        PageViewDirection.left => PageViewDirection.up,
                        PageViewDirection.up => PageViewDirection.right,
                      };
                    });
                  },
                  icon: Icon(() {
                    return switch (_scrollDirection) {
                      PageViewDirection.right => Icons.arrow_forward,
                      PageViewDirection.down => Icons.arrow_downward,
                      PageViewDirection.left => Icons.arrow_back,
                      PageViewDirection.up => Icons.arrow_upward,
                    };
                  }()),
                ),
                // Toggle overscroll
                IconButton(
                  onPressed: () {
                    setState(() {
                      _overshoot = !_overshoot;
                    });
                  },
                  icon: Icon(
                    _overshoot ? Icons.swipe_vertical : Icons.crop_free,
                  ),
                ),
                // Toggle scroll gravity
                IconButton(
                  onPressed: () {
                    setState(() {
                      _scrollGravity = switch (_scrollGravity) {
                        PageViewGravity.start => PageViewGravity.center,
                        PageViewGravity.center => PageViewGravity.end,
                        PageViewGravity.end => PageViewGravity.start,
                      };
                    });
                  },
                  icon: Icon(() {
                    return switch (_scrollGravity) {
                      PageViewGravity.start => Icons.align_vertical_top,
                      PageViewGravity.center => Icons.align_vertical_center,
                      PageViewGravity.end => Icons.align_vertical_bottom,
                    };
                  }()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Buffered extends StatelessWidget {
  const Buffered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(
        Duration(milliseconds: _random.nextInt(1000) + 1000),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return child;
        } else {
          return SizedBox(
            width: 300,
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
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

    return Container(
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
