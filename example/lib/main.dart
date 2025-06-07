import 'dart:math';

import 'package:flutter/material.dart';
import 'package:manga_page_view/manga_page_view.dart';

void main() {
  runApp(const MangaPagesExampleApp());
}

class MangaPagesExampleApp extends StatelessWidget {
  const MangaPagesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Pages Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Manga Pages')),
        body: MangaPageView.builder(
          itemCount: 26,
          itemBuilder: (context, index) {
            final letter = String.fromCharCode(65 + index);
            return Buffered(child: RandomPage(label: 'Page $letter'));
          },
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
      future: Future.delayed(Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return child;
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

class RandomPage extends StatelessWidget {
  const RandomPage({super.key, required this.label});

  final String label;

  static final _random = Random();

  @override
  Widget build(BuildContext context) {
    final width = _random.nextInt(750) + 250;
    final height = _random.nextInt(750) + 250;
    final color = Color(0xFF000000 | _random.nextInt(0xFFFFFF));
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
