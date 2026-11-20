
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <vector>

#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Dart <-> C++ 通道。
  std::unique_ptr<
      flutter::MethodChannel<flutter::EncodableValue>> hotkey_channel_;

  // 当前已经成功注册的热键 ID。
  std::vector<int> registered_hotkey_ids_;

  // 最近一次注册失败时的 Windows 错误码。
  DWORD last_hotkey_error_ = ERROR_SUCCESS;

  bool RegisterHotkeys();
  void UnregisterHotkeys();
  void DispatchHotkey(int hotkey_id);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
