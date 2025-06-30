# MangaPageView

A Flutter widget designed to display comic and manga pages with intuitive navigation and customization options.

[![pub package](https://img.shields.io/pub/v/manga_page_view.svg)](https://pub.dev/packages/manga_page_view)

## Showcase

- Continuous mode

![Continuous mode](https://github.com/amuhaimin02/manga_page_view/raw/main/showcase/continuous1.gif)

- Paged mode

![Paged mode](https://github.com/amuhaimin02/manga_page_view/raw/main/showcase/paged1.gif)

## Features

* Two styles of view
  * Continuous (for long strip or webtoons) 
  * Paged (one page on screen at a time)
* Four way reading direction: top-down, bottom-up, left-to-right, right-to-left
* Common pan and zoom gestures
  * Double tap to zoom
  * Pinch to zoom
  * Double tap and drag to zoom in/out
* Mouse and trackpad support (mouse wheel, two-finger-swipe pan, pinch on trackpad).
* Edge gestures (previous/next chapters, etc)
* Toggleable overscroll options (vertical, horizontal, zooming)
* Internal widget precache - configurable
* Simplistic widget setup using `pageCount` and `pageBuilder`
* Supports any widget as a page, not limited to `Image` widgets
* Very lightweight - only Flutter as dependency
* Usable on all Flutter-supported platforms (mobile, web, desktop)

## Examples

- Minimal usage
```dart
MangaPageView(
  mode: MangaPageViewMode.continuous,
  direction: MangaPageViewDirection.down,
  pageCount: 10, 
  pageBuilder: (context, index) {
    return Container(
      width: 500,
      height: 1500,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.grey.shade500, width: 8),
      ),
      alignment: Alignment.center,
      child: Text(
        'Page ${index + 1}',
        style: TextStyle(
          color: Colors.black,
          fontSize: 48,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  },
);
```

- Extended usage
```dart
MangaPageView(
  mode: MangaPageViewMode.continuous, // Long horizontal strip
  direction: MangaPageViewDirection.right, // Right-to-left reading
  options: const MangaPageViewOptions(
    minZoomLevel: 0.5,
    maxZoomLevel: 8.0,
    initialZoomLevel: 1.0,
    presetZoomLevels: [1.0, 2.0, 4.0, 8.0],
    pageSenseGravity: MangaPageViewGravity.center,
    pageJumpGravity: MangaPageViewGravity.center,
    initialPageSize: Size(
      600,
      800,
    ), // Space to occupy when page widget not loaded yet
    pageWidthLimit: 1000, // Page width never exceeds this amount
    spacing: 16.0, // Spaces between pages
    padding: EdgeInsets.all(8.0), // Spaces around pages
    precacheAhead: 3, // Always load 3 pages ahead
    precacheBehind: 3, // Always load 3 pages behind
    mainAxisOverscroll:
        false, // Restrict horizontal axis from overscrolling
    crossAxisOverscroll:
        false, // Restrict vertical axis from overscrolling
    zoomOvershoot: true, // Overshoot when zooming gives a bit of fluidity
    zoomOnFocalPoint: true, // If false, zooming point will be on center
  ),
  controller:
      MangaPageViewController(), // For programmatic control. Best to put it as a field
  pageCount: 20,
  pageBuilder: (context, index) {
    // Replace with your actual page widget, perhaps an Image
    // Tips: always provide sizes or padding to your loading and error widgets
    return Image.network(
      'https://picsum.photos/600/800?t=$index',
      fit: BoxFit
          .contain, // Try to fit and constrain image to available size
      loadingBuilder: (context, child, loadingProgress) {
        // Even your loading widget needs some space
        return Container(
          padding: EdgeInsets.all(24),
          alignment: Alignment.center,
          child: CircularProgressIndicator(),
        ),
      }
    );
  },
  onPageChange: (index) {
    print('Current page: $index');
  },
  onZoomChange: (zoomLevel) {
    print('Current zoom: $zoomLevel');
  },
  onProgressChange: (progress) {
    print('Scroll progress: $progress');
  },
  startEdgeDragIndicatorBuilder: (context, info) {
    // Previous chapter indicator
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Icon(Icons.skip_previous, size: 48),
    );
  },
  endEdgeDragIndicatorBuilder: (context, info) {
    // Next chapter indicator
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Icon(Icons.skip_next, size: 48),
    );
  },
  onStartEdgeDrag: () {
    print('Dragging from the start edge');
  },
  onEndEdgeDrag: () {
    print('Dragging from the end edge');
  },
);
```

## More info
Refer to the documentation and examples for more information and detailed usage.
