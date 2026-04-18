#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <inputpaneinterop.h>
#include <optional>
#include <winrt/Windows.UI.ViewManagement.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool InvokeInputPane(HWND window, bool show) {
  if (!window) {
    return false;
  }

  try {
    auto const factory = winrt::get_activation_factory<
        winrt::Windows::UI::ViewManagement::InputPane, IInputPaneInterop>();
    winrt::Windows::UI::ViewManagement::IInputPane2 input_pane{nullptr};
    HRESULT result = factory->GetForWindow(
        window, winrt::guid_of<winrt::Windows::UI::ViewManagement::IInputPane2>(),
        winrt::put_abi(input_pane));
    if (FAILED(result) || !input_pane) {
      return false;
    }
    return show ? input_pane.TryShow() : input_pane.TryHide();
  } catch (...) {
    return false;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  system_keyboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "epos/system_keyboard",
          &flutter::StandardMethodCodec::GetInstance());
  system_keyboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "show") {
          result->Success(flutter::EncodableValue(InvokeInputPane(GetHandle(), true)));
          return;
        }
        if (call.method_name() == "hide") {
          result->Success(flutter::EncodableValue(InvokeInputPane(GetHandle(), false)));
          return;
        }
        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  system_keyboard_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
