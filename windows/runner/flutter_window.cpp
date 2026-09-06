#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Generická detekce aktivního screen readeru na Windows.
//
// Kombinuje dvě oficiální Windows API, aby pokryla NVDA, JAWS i Narrator
// bez závislosti na názvu konkrétního procesu:
//  1) SystemParametersInfoW(SPI_GETSCREENREADER) – příznak nastavený
//     čtečkou přes SPI_SETSCREENREADER (NVDA, JAWS, ...).
//  2) UiaClientsAreListening() z UIAutomationCore.dll – zda právě
//     naslouchá nějaký UI Automation klient (NVDA / JAWS / Narrator).
// Vrací true, pokud kterékoliv hlásí aktivní čtečku. Nikdy nevyhazuje,
// při jakékoliv chybě vrací false (Dart pak použije Flutter fallback).
// Samostatná SEH funkce bez C++ try/catch (MSVC C2712 nedovoluje
// __try ve funkci s object unwinding). Volá UiaClientsAreListening,
// při SEH výjimce vrací FALSE.
static BOOL QueryUiaClientsAreListening() noexcept {
  HMODULE uia_lib = ::LoadLibraryW(L"UIAutomationCore.dll");
  if (uia_lib == nullptr) {
    return FALSE;
  }
  using UiaClientsAreListeningFn = BOOL(WINAPI*)();
  auto fn = reinterpret_cast<UiaClientsAreListeningFn>(
      ::GetProcAddress(uia_lib, "UiaClientsAreListening"));
  BOOL listening = FALSE;
  if (fn != nullptr) {
    __try {
      listening = fn();
    } __except (EXCEPTION_EXECUTE_HANDLER) {
      listening = FALSE;
    }
  }
  ::FreeLibrary(uia_lib);
  return listening;
}

bool IsScreenReaderEnabled() noexcept {
  // 1) SPI_GETSCREENREADER
  try {
    BOOL screen_reader = FALSE;
    if (::SystemParametersInfoW(SPI_GETSCREENREADER, 0, &screen_reader, 0) &&
        screen_reader) {
      return true;
    }
  } catch (...) {
    // Ignoruj a pokračuj na UIA kontrolu.
  }

  // 2) UiaClientsAreListening (dynamicky, bez linkovací závislosti).
  try {
    if (QueryUiaClientsAreListening()) {
      return true;
    }
  } catch (...) {
    // Ignoruj, vrať false.
  }
  return false;
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

  // Nativní detekce screen readeru pro Dart (stejný kanál jako na Androidu,
  // samostatná metoda pro Windows). Bezpečná: při chybě vrátí Error,
  // aby Dart použil Flutter fallback, nikdy neshodí aplikaci.
  try {
    accessibility_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            flutter_controller_->engine()->messenger(),
            "com.example.mluvici_kalkulacka/accessibility",
            &flutter::StandardMethodCodec::GetInstance());
    accessibility_channel_->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
               result) {
          try {
            if (call.method_name() == "isScreenReaderEnabled") {
              const bool enabled = IsScreenReaderEnabled();
              result->Success(flutter::EncodableValue(enabled));
            } else {
              result->NotImplemented();
            }
          } catch (...) {
            result->Error("UNAVAILABLE",
                          "Unable to determine screen reader state.");
          }
        });
  } catch (...) {
    // Když se kanál nepodaří vytvořit, Dart spadne do Flutter fallbacku.
    accessibility_channel_.reset();
  }

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
  // Kanál uvolnit dřív než engine, aby handler nevolal do mrtvého enginu.
  accessibility_channel_.reset();
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
