#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <sddl.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {
std::wstring InstanceMutexName() {
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) return {};
  DWORD size = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  const BOOL success = ::GetTokenInformation(token, TokenUser, buffer.data(),
                                            size, &size);
  ::CloseHandle(token);
  if (!success) return {};
  LPWSTR sid = nullptr;
  if (!::ConvertSidToStringSidW(
          reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid)) return {};
  std::wstring name = L"Global\\Vasmim.Library.";
  name += sid;
  ::LocalFree(sid);
  return name;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One writer per Windows user, across sessions and versions of Vasmim.
  const std::wstring mutex_name = InstanceMutexName();
  HANDLE instance_mutex = mutex_name.empty()
      ? nullptr : ::CreateMutexW(nullptr, TRUE, mutex_name.c_str());
  if (!instance_mutex) {
    ::MessageBoxW(nullptr, L"Vasmim could not protect its Library. Please try again.",
                  L"Vasmim", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(instance_mutex);
    HWND existing = ::FindWindowW(nullptr, L"Vasmim");
    if (existing) {
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    } else {
      ::MessageBoxW(nullptr, L"Vasmim is already running. Use the open window.",
                    L"Vasmim", MB_OK | MB_ICONINFORMATION);
    }
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Vasmim", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(instance_mutex);
  ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
