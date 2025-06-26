# MangaPageView

A Flutter widget designed to display comic and manga pages with intuitive navigation and customization options.

## Showcase

- Continuous mode
![Continuous mode](https://github.com/amuhaimin02/manga_page_view/raw/main/showcase/continuous1.gif)

- Paged mode
![Paged mode](https://github.com/amuhaimin02/manga_page_view/raw/main/showcase/paged1.gif)

## Features

* Two modes: continuous (webtoon, long strip) or paged
* Four way reading direction: top-down, bottom-up, left-to-right, right-to-left
* Common pan and zoom gestures
  * Double tap to zoom
  * Pinch to zoom
  * Double tap and drag to zoom in/out
* Mouse and trackpad support (mouse wheel, two-finger-swipe pan, pinch on trackpad)
* Edge gestures (previous/next chapters, etc)
* Toggleable overscroll options (vertical, horizontal, zooming)
* Internal widget precache
* Simplistic widget setup using `pageCount` and `pageBuilder`
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

- Extensive usage
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
    pageWidthLimit: 1000, // Page width never exceeds this amount of width
    spacing: 16.0, // Spaces between pages
    padding: EdgeInsets.all(8.0), // Spaces around pages
    precacheAhead: 3, // Always load 3 page ahead from current
    precacheBehind: 3, // Always load 3 page behind from current
    mainAxisOverscroll:
        false, // Restrict horizontal axis from overscrolling
    crossAxisOverscroll:
        false, // Restrict horizontal axis from overscrolling
    zoomOvershoot: true, // Overshoot when zooming gives fluidity
    zoomOnFocalPoint: true,
  ),
  controller:
      MangaPageViewController(), // For programmatic control. Best to put it as a field
  pageCount: 20,
  pageBuilder: (context, index) {
    // Replace with your actual page widget, perhaps an Image
    // Tips: always provide sizes or padding to your loading and error widgets, if available
    return Image.network(
      'https://picsum.photos/600/800?t=$index',
      fit: BoxFit
          .contain, // Try to fit and constrain image to available size
      loadingBuilder: (context, child, loadingProgress) => Container(
        padding: EdgeInsets.all(24),
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      ),
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
