
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/window_info.dart';
import '../../models/window_style_backup.dart';

/// Windows 窗口 API 封装。
///
/// 负责调用 Win32 API 获取窗口信息，不处理 UI。
class WindowApi {
  /// 获取当前所有可见且具有标题的顶层窗口。
  List<WindowInfo> enumerateWindows() {
    final windows = <WindowInfo>[];

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((
      Pointer hWnd,
      int lParam,
    ) {
      final hwnd = HWND(hWnd);

      // 忽略不可见窗口。
      if (!IsWindowVisible(hwnd)) return TRUE;

      // 忽略没有标题的窗口。
      final length = GetWindowTextLength(hwnd).value;
      if (length <= 0) return TRUE;

      using((arena) {
        // 获取窗口标题。
        final titleBuffer = arena.pwstrBuffer(length + 1);
        final titleLength = GetWindowText(
          hwnd,
          titleBuffer,
          length + 1,
        );

        if (titleLength.value <= 0) return;

        // 获取进程 PID。
        final processIdPointer = arena<Uint32>();
        GetWindowThreadProcessId(hwnd, processIdPointer);
        final processId = processIdPointer.value;

        // 获取窗口矩形。
        final rectPointer = arena<RECT>();
        final rectResult = GetWindowRect(hwnd, rectPointer);

        var x = 0;
        var y = 0;
        var width = 0;
        var height = 0;

        if (rectResult.value) {
          final rect = rectPointer.ref;

          x = rect.left;
          y = rect.top;
          width = rect.right - rect.left;
          height = rect.bottom - rect.top;
        }

        // 保存窗口信息快照。
        windows.add(
          WindowInfo(
            handle: hWnd.address,
            title: titleBuffer.toDartString(),
            processId: processId,
            x: x,
            y: y,
            width: width,
            height: height,
            isMinimized: IsIconic(hwnd),
            isMaximized: IsZoomed(hwnd),
          ),
        );
      });

      return TRUE;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, LPARAM(0));
    } finally {
      callback.close();
    }

    return windows;
  }

  /// Win32 常量。
  static const int _wsExLayered = 0x00080000;
  static const int _lwaAlpha = 0x00000002;

  /// 获取并备份目标窗口的原始样式。
  WindowStyleBackup captureWindowStyle({
    required int handle,
    required int processId,
  }) {
    final hwnd = HWND(Pointer.fromAddress(handle));

    if (!IsWindow(hwnd)) {
      throw Exception('窗口已经失效');
    }

    // 防止 HWND 被系统重新分配给其他进程。
    final pidPointer = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pidPointer);

      if (pidPointer.value != processId) {
        throw Exception('窗口所属进程已经发生变化');
      }
    } finally {
      calloc.free(pidPointer);
    }

    final styleResult = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    final style = styleResult.value;
    final originallyLayered = (style & _wsExLayered) != 0;

    int? alpha;
    int? colorKey;
    int? flags;

    // 已经是 layered window 时，必须先读取原有属性。
    if (originallyLayered) {
      final keyPointer = calloc<Uint32>();
      final alphaPointer = calloc<Uint8>();
      final flagsPointer = calloc<Uint32>();

      try {
        final result = GetLayeredWindowAttributes(
          hwnd,
          keyPointer,
          alphaPointer,
          flagsPointer,
        );

        if (!result.value) {
          throw Exception(
            '无法读取窗口原有透明度属性，已取消修改',
          );
        }

        alpha = alphaPointer.value;
        colorKey = keyPointer.value;
        flags = flagsPointer.value;
      } finally {
        calloc.free(keyPointer);
        calloc.free(alphaPointer);
        calloc.free(flagsPointer);
      }
    }

    return WindowStyleBackup(
      handle: handle,
      processId: processId,
      originalExtendedStyle: style,
      originallyLayered: originallyLayered,
      originalAlpha: alpha,
      originalColorKey: colorKey,
      originalFlags: flags,
    );
  }

  /// 设置目标窗口透明度。
  ///
  /// alpha: 0～255，0 完全透明，255 完全不透明。
  void setWindowOpacity(int handle, int alpha) {
    if (alpha < 0 || alpha > 255) {
      throw RangeError.range(alpha, 0, 255, 'alpha');
    }

    final hwnd = HWND(Pointer.fromAddress(handle));

    if (!IsWindow(hwnd)) {
      throw Exception('窗口已经失效');
    }

    final style = GetWindowLongPtr(hwnd, GWL_EXSTYLE).value;

    // 必要时添加 WS_EX_LAYERED。
    if ((style & _wsExLayered) == 0) {
      final result = SetWindowLongPtr(
        hwnd,
        GWL_EXSTYLE,
        style | _wsExLayered,
      );

      if (result.value == 0 && result.error != ERROR_SUCCESS) {
        throw Exception('无法设置窗口扩展样式');
      }
    }

    final result = SetLayeredWindowAttributes(
      hwnd,
      const COLORREF(0),
      alpha,
      LAYERED_WINDOW_ATTRIBUTES_FLAGS(_lwaAlpha),
    );

    if (!result.value) {
      throw Exception('设置窗口透明度失败');
    }
  }

  /// 恢复目标窗口原始样式。
  void restoreWindowStyle(WindowStyleBackup backup) {
    final hwnd = HWND(Pointer.fromAddress(backup.handle));

    if (!IsWindow(hwnd)) {
      throw Exception('窗口已经失效，无需恢复');
    }

    // 再次检查 PID，避免误操作复用的 HWND。
    final pidPointer = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pidPointer);

      if (pidPointer.value != backup.processId) {
        throw Exception('窗口所属进程已经变化，取消恢复');
      }
    } finally {
      calloc.free(pidPointer);
    }

    // 先恢复扩展样式。
    final styleResult = SetWindowLongPtr(
      hwnd,
      GWL_EXSTYLE,
      backup.originalExtendedStyle,
    );

    if (styleResult.value == 0 &&
        styleResult.error != ERROR_SUCCESS) {
      throw Exception('恢复窗口扩展样式失败');
    }

    // 原本就是 layered window，则恢复原有属性。
    if (backup.originallyLayered) {
      final result = SetLayeredWindowAttributes(
        hwnd,
        COLORREF(backup.originalColorKey!),
        backup.originalAlpha!,
        LAYERED_WINDOW_ATTRIBUTES_FLAGS(backup.originalFlags!),
      );

      if (!result.value) {
        throw Exception('恢复窗口透明度属性失败');
      }
    }
  }
}
