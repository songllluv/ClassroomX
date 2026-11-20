/// 窗口透明度修改前的原始状态。
///
/// 用于在用户手动恢复或 ClassroomX 退出时还原窗口。
class WindowStyleBackup {
  const WindowStyleBackup({
    required this.handle,
    required this.processId,
    required this.originalExtendedStyle,
    required this.originallyLayered,
    this.originalAlpha,
    this.originalColorKey,
    this.originalFlags,
  });

  /// HWND。不能单独依靠它识别窗口，因为句柄可能被系统复用。
  final int handle;

  /// 创建该窗口的进程 PID。
  final int processId;

  /// 修改前的扩展窗口样式。
  final int originalExtendedStyle;

  /// 修改前是否已经具有 WS_EX_LAYERED。
  final bool originallyLayered;

  /// 原始 Alpha 值。
  final int? originalAlpha;

  /// 原始颜色键。
  final int? originalColorKey;

  /// 原始 layered 属性标志。
  final int? originalFlags;
}