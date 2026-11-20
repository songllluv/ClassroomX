
class WindowInfo {
  const WindowInfo({
    required this.handle,
    required this.title,
    required this.processId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isMinimized,
    required this.isMaximized,
  });

  final int handle;
  final String title;
  final int processId;

  final int x;
  final int y;
  final int width;
  final int height;

  final bool isMinimized;
  final bool isMaximized;

  String get handleText =>
      '0x${handle.toRadixString(16).toUpperCase()}';
}
