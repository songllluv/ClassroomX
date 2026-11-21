
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <vector>

#include "overlay_manager.h"
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

  // Dart <-> C++ hotkey channel.
  std::unique_ptr<
      flutter::MethodChannel<flutter::EncodableValue>> hotkey_channel_;

  // Dart <-> C++ protection overlay channel.
  std::unique_ptr<
      flutter::MethodChannel<flutter::EncodableValue>> protection_channel_;

  OverlayManager overlay_manager_;

  // Successfully registered global hotkey IDs.
  std::vector<int> registered_hotkey_ids_;

  // Last Windows error returned by RegisterHotKey.
  DWORD last_hotkey_error_ = ERROR_SUCCESS;

  bool RegisterHotkeys();
  void UnregisterHotkeys();
  void DispatchHotkey(int hotkey_id);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
