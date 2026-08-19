#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "theme_win10.h"
#include "theme_win11.h"

namespace {
// RTL version structure for ntdll check
typedef struct _RTL_OSVERSIONINFOW {
  ULONG dwOSVersionInfoSize;
  ULONG dwMajorVersion;
  ULONG dwMinorVersion;
  ULONG dwBuildNumber;
  ULONG dwPlatformId;
  WCHAR szCSDVersion[128];
} RTL_OSVERSIONINFOW, *PRTL_OSVERSIONINFOW;

typedef void (WINAPI *RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

bool IsWindows11OrGreater() {
  HMODULE hMod = GetModuleHandleA("ntdll.dll");
  if (hMod) {
    RtlGetVersionPtr pRtlGetVersion = (RtlGetVersionPtr)GetProcAddress(hMod, "RtlGetVersion");
    if (pRtlGetVersion) {
      RTL_OSVERSIONINFOW osvi = { 0 };
      osvi.dwOSVersionInfoSize = sizeof(osvi);
      pRtlGetVersion(&osvi);
      return osvi.dwMajorVersion > 10 || (osvi.dwMajorVersion == 10 && osvi.dwBuildNumber >= 22000);
    }
  }
  return false;
}

struct FindWindowParams {
  DWORD pid;
  std::wstring title;
  HWND found;
};

static BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
  FindWindowParams* params = reinterpret_cast<FindWindowParams*>(lParam);
  DWORD processId = 0;
  GetWindowThreadProcessId(hwnd, &processId);
  if (processId == params->pid) {
    wchar_t windowTitle[256];
    if (GetWindowTextW(hwnd, windowTitle, 256) > 0) {
      if (params->title == windowTitle) {
        params->found = hwnd;
        return FALSE; // Stop enumerating
      }
    }
  }
  return TRUE; // Continue enumerating
}
} // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  auto messenger = flutter_controller_->engine()->messenger();
  theme_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "ja_route/theme",
      &flutter::StandardMethodCodec::GetInstance());

  theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "updateTheme") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          bool is_dark = true;
          if (arguments) {
            auto is_dark_it = arguments->find(flutter::EncodableValue("isDark"));
            if (is_dark_it != arguments->end() && !is_dark_it->second.IsNull()) {
              if (std::holds_alternative<bool>(is_dark_it->second)) {
                is_dark = std::get<bool>(is_dark_it->second);
              }
            }
          }

          HWND hwnd = GetHandle();
          if (hwnd) {
            if (IsWindows11OrGreater()) {
              ApplyThemeWin11(hwnd, is_dark, false);
            } else {
              ApplyThemeWin10(hwnd, is_dark);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  mirror_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "ja_route/mirror",
      &flutter::StandardMethodCodec::GetInstance());

  mirror_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "embedMirror") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          std::wstring title = L"JA_ADB_Tool_Mirror";
          double tx = 0, ty = 0, tw = 0, th = 0;
          DWORD target_pid = 0;
          if (arguments) {
            auto title_it = arguments->find(flutter::EncodableValue("title"));
            if (title_it != arguments->end() && !title_it->second.IsNull() && std::holds_alternative<std::string>(title_it->second)) {
              std::string s_title = std::get<std::string>(title_it->second);
              title = std::wstring(s_title.begin(), s_title.end());
            }
            auto pid_it = arguments->find(flutter::EncodableValue("pid"));
            if (pid_it != arguments->end() && std::holds_alternative<int32_t>(pid_it->second)) {
              target_pid = static_cast<DWORD>(std::get<int32_t>(pid_it->second));
            }
            // Read optional target rect so we can position before showing
            auto rx = arguments->find(flutter::EncodableValue("x"));
            auto ry = arguments->find(flutter::EncodableValue("y"));
            auto rw = arguments->find(flutter::EncodableValue("width"));
            auto rh = arguments->find(flutter::EncodableValue("height"));
            if (rx != arguments->end() && std::holds_alternative<double>(rx->second)) tx = std::get<double>(rx->second);
            if (ry != arguments->end() && std::holds_alternative<double>(ry->second)) ty = std::get<double>(ry->second);
            if (rw != arguments->end() && std::holds_alternative<double>(rw->second)) tw = std::get<double>(rw->second);
            if (rh != arguments->end() && std::holds_alternative<double>(rh->second)) th = std::get<double>(rh->second);
          }

          HWND hwndScrcpy = nullptr;
          if (target_pid > 0) {
            FindWindowParams params = { target_pid, title, nullptr };
            EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&params));
            hwndScrcpy = params.found;
          } else {
            // Fallback
            hwndScrcpy = FindWindowW(NULL, title.c_str());
          }
          if (hwndScrcpy) {
            hwnd_scrcpy_ = hwndScrcpy;
            // Reset cached position so next update always applies
            last_x_ = last_y_ = last_w_ = last_h_ = -1;

            // Use the Flutter view as the parent so it properly clips its DirectX swap chain 
            // around the child window (requires WS_CLIPCHILDREN on the Flutter view).
            HWND hwndParent = flutter_controller_->view()->GetNativeWindow();

            // Add WS_CLIPCHILDREN to parent so it doesn't overdraw the child area
            LONG_PTR parentStyle = GetWindowLongPtr(hwndParent, GWL_STYLE);
            parentStyle |= WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
            SetWindowLongPtr(hwndParent, GWL_STYLE, parentStyle);

            // Set parenting FIRST (window is still invisible at this point)
            SetParent(hwndScrcpy, hwndParent);

            // Modify styles to make it a child window
            // CRITICAL: We DO NOT remove WS_CAPTION or borders! Removing them confuses SDL's 
            // internal mouse coordinate translation and viewport resizing.
            // Instead, we will crop them out using SetWindowRgn.
            LONG_PTR style = GetWindowLongPtr(hwndScrcpy, GWL_STYLE);
            style &= ~WS_POPUP;
            style |= WS_CHILD | WS_CLIPSIBLINGS;
            SetWindowLongPtr(hwndScrcpy, GWL_STYLE, style);

            // Apply style changes (forces frame recalculation while window is still hidden)
            SetWindowPos(hwndScrcpy, HWND_TOP, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);

            // If we have a valid target rect, position and crop the window
            bool hasRect = (tw > 0 && th > 0);
            if (hasRect) {
              int ix = static_cast<int>(tx), iy = static_cast<int>(ty),
                  iw = static_cast<int>(tw), ih = static_cast<int>(th);
              last_x_ = ix; last_y_ = iy; last_w_ = iw; last_h_ = ih;
              
              RECT rect = { 0, 0, iw, ih };
              LONG_PTR exStyle = GetWindowLongPtr(hwndScrcpy, GWL_EXSTYLE);
              AdjustWindowRectEx(&rect, static_cast<DWORD>(style), FALSE, static_cast<DWORD>(exStyle));
              
              int win_w = rect.right - rect.left;
              int win_h = rect.bottom - rect.top;
              int offset_x = -rect.left;
              int offset_y = -rect.top;

              HRGN hRgn = CreateRectRgn(offset_x, offset_y, offset_x + iw, offset_y + ih);
              SetWindowRgn(hwndScrcpy, hRgn, TRUE);

              // Move/resize and show the window using SetWindowPos
              SetWindowPos(hwndScrcpy, HWND_TOP, ix - offset_x, iy - offset_y, win_w, win_h,
                           SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_NOCOPYBITS);
            } else {
              // Fallback: show window if no rect provided
              ShowWindow(hwndScrcpy, SW_SHOWNOACTIVATE);
            }

            // Force an immediate paint so content appears without needing a screenshot
            RedrawWindow(hwndScrcpy, NULL, NULL,
                         RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN);
            UpdateWindow(hwndScrcpy);

            result->Success(flutter::EncodableValue(true));
          } else {
            result->Success(flutter::EncodableValue(false));
          }
        } else if (call.method_name() == "updateMirrorPosition") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          double x = 0, y = 0, w = 0, h = 0;
          if (arguments) {
            auto x_it = arguments->find(flutter::EncodableValue("x"));
            auto y_it = arguments->find(flutter::EncodableValue("y"));
            auto w_it = arguments->find(flutter::EncodableValue("width"));
            auto h_it = arguments->find(flutter::EncodableValue("height"));

            if (x_it != arguments->end() && !x_it->second.IsNull()) {
              if (std::holds_alternative<double>(x_it->second)) x = std::get<double>(x_it->second);
              else if (std::holds_alternative<int32_t>(x_it->second)) x = std::get<int32_t>(x_it->second);
            }
            if (y_it != arguments->end() && !y_it->second.IsNull()) {
              if (std::holds_alternative<double>(y_it->second)) y = std::get<double>(y_it->second);
              else if (std::holds_alternative<int32_t>(y_it->second)) y = std::get<int32_t>(y_it->second);
            }
            if (w_it != arguments->end() && !w_it->second.IsNull()) {
              if (std::holds_alternative<double>(w_it->second)) w = std::get<double>(w_it->second);
              else if (std::holds_alternative<int32_t>(w_it->second)) w = std::get<int32_t>(w_it->second);
            }
            if (h_it != arguments->end() && !h_it->second.IsNull()) {
              if (std::holds_alternative<double>(h_it->second)) h = std::get<double>(h_it->second);
              else if (std::holds_alternative<int32_t>(h_it->second)) h = std::get<int32_t>(h_it->second);
            }
          }

          if (hwnd_scrcpy_ && IsWindow(hwnd_scrcpy_)) {
            int ix = static_cast<int>(x), iy = static_cast<int>(y),
                iw = static_cast<int>(w), ih = static_cast<int>(h);
            // Only move/resize if position actually changed to avoid unnecessary repaints
            bool hiding = (iw == 0 && ih == 0);
            if (hiding) {
              // Move offscreen to hide without destroying embedding
              if (last_x_ != -9999) {
                MoveWindow(hwnd_scrcpy_, -32000, -32000, 1, 1, FALSE);
                last_x_ = -9999;
              }
            } else {
              last_x_ = ix; last_y_ = iy; last_w_ = iw; last_h_ = ih;
              
              RECT rect = { 0, 0, iw, ih };
              LONG_PTR style = GetWindowLongPtr(hwnd_scrcpy_, GWL_STYLE);
              LONG_PTR exStyle = GetWindowLongPtr(hwnd_scrcpy_, GWL_EXSTYLE);
              AdjustWindowRectEx(&rect, static_cast<DWORD>(style), FALSE, static_cast<DWORD>(exStyle));
              
              int win_w = rect.right - rect.left;
              int win_h = rect.bottom - rect.top;
              int offset_x = -rect.left;
              int offset_y = -rect.top;

              HRGN hRgn = CreateRectRgn(offset_x, offset_y, offset_x + iw, offset_y + ih);
              SetWindowRgn(hwnd_scrcpy_, hRgn, TRUE);

              // Move/resize the child window. SWP_NOCOPYBITS discards stale
              // bits on resize; we rely on scrcpy's own render loop to repaint.
              // Do NOT use SWP_NOREDRAW — that prevents paint entirely.
              SetWindowPos(hwnd_scrcpy_, HWND_TOP, ix - offset_x, iy - offset_y, win_w, win_h,
                           SWP_NOACTIVATE | SWP_NOCOPYBITS);
              // Flush the paint queue for the child immediately
              UpdateWindow(hwnd_scrcpy_);
            }
            result->Success(flutter::EncodableValue(true));
          } else {
            result->Success(flutter::EncodableValue(false));
          }
        } else if (call.method_name() == "unembedMirror") {
          if (hwnd_scrcpy_ && IsWindow(hwnd_scrcpy_)) {
            SetParent(hwnd_scrcpy_, NULL);
            LONG_PTR style = GetWindowLongPtr(hwnd_scrcpy_, GWL_STYLE);
            style &= ~WS_CHILD;
            style |= WS_POPUP | WS_CAPTION | WS_SYSMENU;
            SetWindowLongPtr(hwnd_scrcpy_, GWL_STYLE, style);
            SetWindowPos(hwnd_scrcpy_, NULL, 100, 100, 400, 800, SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
          }
          hwnd_scrcpy_ = nullptr;
          last_x_ = last_y_ = last_w_ = last_h_ = -1;
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Show the window only after Flutter renders its first frame (avoids blank
  // flash). On some Windows 10 setups the vsync signal is suppressed for
  // hidden windows, so the callback never fires and the app freezes. We arm a
  // 300 ms fallback WM_TIMER so the window is guaranteed to appear.
  HWND hwnd = GetHandle();
  ::SetTimer(hwnd, kShowFallbackTimerId, 300, nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (!window_shown_) {
      window_shown_ = true;
      HWND hwnd = GetHandle();
      ::KillTimer(hwnd, kShowFallbackTimerId);
      this->Show();
    }
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (hwnd_scrcpy_ && IsWindow(hwnd_scrcpy_)) {
    PostMessage(hwnd_scrcpy_, WM_CLOSE, 0, 0);
    hwnd_scrcpy_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::RemovePropW(hwnd, L"JA_ADB_TOOL_INSTANCE");
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_TIMER:
      if (wparam == kShowFallbackTimerId) {
        ::KillTimer(hwnd, kShowFallbackTimerId);
        if (!window_shown_) {
          window_shown_ = true;
          this->Show();
          // Force a redraw so the Flutter layer paints immediately
          if (flutter_controller_) {
            flutter_controller_->ForceRedraw();
          }
        }
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
