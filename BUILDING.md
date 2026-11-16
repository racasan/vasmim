# Building Vasmim

Vasmim is a Flutter desktop application for Windows x64.

## Prerequisites

- Windows 10 or 11, x64.
- [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop)
  stable with Dart 3.12 or newer. The release was built with Flutter 3.44.8.
- Visual Studio with the **Desktop development with C++** workload.
- Internet access for the first build. Flutter downloads the packages in
  `pubspec.lock`, and the Windows build downloads the pinned PDFium archive
  and the prebuilt native clipboard library.

`NuGet.Config` in the repository root supplies the official NuGet feed that one
Windows plugin needs.

## Develop

```powershell
flutter pub get
flutter run -d windows
```

Before submitting a change:

```powershell
dart format lib test
flutter analyze
flutter test
```

Some tests in `test/release/` run the PowerShell packaging scripts, so the full
suite needs Windows.

## Release build

```powershell
flutter build windows --release
```

The runnable application is the whole folder
`build\windows\x64\runner\Release\`, not `vasmim.exe` alone.

The build verifies PDFium before compiling: `windows/pdfium/verify.cmake` pins
the archive's SHA-256 and `windows/pdfium/package.sha256` lists every package
file. If a guard fails, investigate the mismatch; do not regenerate the hashes
to make it pass. Changing the PDFium version means reviewing the new version
and its notices, then updating both pins.

During the build, the clipboard plugin may print a PowerShell warning about a
hidden `AppData` directory. It is harmless when the build finishes
successfully.

## Package the portable ZIP

The published ZIP is produced from a release build in three steps. None of the
scripts downloads, installs, or publishes anything.

1. **Build from a neutral folder.** Compiled files record the source location,
   so build from a short path that does not contain your Windows user name,
   for example a copy of the repository in `C:\vasmim-build\src`. Do not build
   at a drive root. Keep debug symbols out of the package:

   ```powershell
   flutter build windows --release --split-debug-info=..\symbols
   ```

2. **Collect the inventory and licence texts** for that exact build:

   ```powershell
   .\tool\inspect_release_payload.ps1 `
     -ReleaseDirectory build\windows\x64\runner\Release `
     -OutputDirectory ..\inventory
   ```

   This writes `runtime_inventory.json` and a `licenses` folder holding the
   licence file of every resolved package, the PDFium notice tree from the
   build, and the collected clipboard and Rust notices from `release/`.

3. **Create the ZIP and its checksum:**

   ```powershell
   .\tool\package_windows_beta.ps1 `
     -ReleaseDirectory build\windows\x64\runner\Release `
     -OutputDirectory ..\artifact `
     -LicenseDirectory ..\inventory\licenses
   ```

   The script refuses to package a build that contains a file it does not
   expect, a local user path, or draft wording in the release documents. Every
   bundled component must have its notices in the package; if you add a
   dependency that ships a native library, add its notices and update
   `release/THIRD_PARTY_NOTICES.md` and the script's file list together.

## Dependency checks

- `tool/audit_security_dependencies.py` screens the versions in
  `pubspec.lock` against the public OSV advisory database. It sends only
  public package names and versions.
- `tool/collect_rust_licence_evidence.py` re-collects the licence texts of the
  native clipboard library's Rust dependencies. Run it when
  `super_native_extensions` changes, and refresh
  `release/CLIPBOARD_THIRD_PARTY_NOTICES.txt`.
