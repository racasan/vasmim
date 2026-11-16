# Repository Guidelines

## Project Structure & Module Organization

Vasmim is a Windows-only Flutter desktop application.

- `lib/main.dart`: application bootstrap and production store wiring.
- `lib/board/`, `lib/canvas/`, `lib/note/` and neighbours: Board serialization and storage, canvas interaction, and the object models and widgets.
- `windows/`: Windows runner and CMake integration, including the PDFium integrity pins. Change it only when native Windows behavior is required.
- `test/`: unit and widget tests, mirroring relevant `lib/` paths such as `test/canvas/` and `test/note/`.
- `release/`: documents and third-party notices shipped in the Windows package.
- `tool/`: packaging and dependency-inventory scripts.
- `pubspec.yaml`: dependencies and SDK constraints.

Do not edit generated output in `build/` or `.dart_tool/`.

## Build, Test, and Development Commands

- `flutter pub get` — resolve dependencies from `pubspec.yaml`.
- `flutter run -d windows` — launch the app locally with hot reload.
- `flutter analyze` — run the lints configured by `analysis_options.yaml`.
- `dart format lib test` — format source and tests.
- `flutter test` — run all unit and widget tests.
- `flutter build windows` — produce a release build under `build/windows/x64/runner/Release/`.

Run analysis and relevant tests before submitting changes. See `BUILDING.md` for packaging.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and allow `dart format` to decide wrapping. Follow `flutter_lints`; do not silence warnings without a documented reason. Name classes and enums in `UpperCamelCase`, files and variables in `lower_snake_case`/`lowerCamelCase`, and tests with descriptive behavior-focused names. Prefer small widgets and the product's own domain names, such as `Board`, `Note`, `Scene`, and `Connector`.

## Testing Guidelines

Use `flutter_test`. Name files `*_test.dart` and group tests by behavior. Add regression tests for canvas transforms, note commands, undo, and Board serialization when those areas change. No numeric coverage target exists; prioritize critical interactions and data preservation.

## Commit & Pull Request Guidelines

Use Conventional Commit-style subjects, for example `feat: add viewport panning` or `test: cover note movement`.

## Dependencies and licensing

Vasmim's own code is under the BSD Zero Clause License. The Windows package must only contain components whose licence texts are collected by `tool/inspect_release_payload.ps1` and described in `release/THIRD_PARTY_NOTICES.md`; the packaging script rejects any other runtime file. Do not add a dependency that bundles a native library without adding its notices and reviewing its licence. In-app audio and movie playback was removed for this reason: the media library it needed (LGPL) had no published matching source.
