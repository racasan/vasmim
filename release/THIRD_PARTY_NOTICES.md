# Third-party materials

Vasmim's own source code is released under the BSD Zero Clause License; see
`LICENSE.txt`. The Windows package also contains the third-party components
below. Each remains under its own licence, and nothing in Vasmim's licence
changes those terms. Their licence and notice texts are included in this
package, in the locations given.

| Component | In the package as | Licence | Notices |
| --- | --- | --- | --- |
| Flutter engine and framework, Dart runtime | `flutter_windows.dll`, `data/app.so`, `data/icudtl.dat` | BSD 3-Clause, with the incorporated components listed in the notices | `data/flutter_assets/NOTICES.Z` and `third_party_licenses/flutter-LICENSE.txt` |
| Dart and Flutter packages compiled into the application | `data/app.so` and the plugin DLLs | Permissive licences (BSD, MIT, Apache 2.0), one per package | `third_party_licenses/<package>-LICENSE` |
| PDFium 158.0.8125.0, Windows x64, V8 and XFA disabled | `pdfium.dll` | BSD 3-Clause and Apache 2.0, plus its incorporated components | `third_party_licenses/pdfium/` and `data/native_licenses/pdfium/`, including `provenance.json` |
| pdfx plugin | `pdfx_plugin.dll` | MIT | `third_party_licenses/pdfx-LICENSE` |
| Native clipboard library and its Rust dependencies | `super_native_extensions.dll`, `super_native_extensions_plugin.dll`, `irondash_engine_context_plugin.dll` | MIT; dependencies under MIT, Apache 2.0, BSD and similar, and one under MPL 2.0 (below) | `third_party_licenses/clipboard-NOTICES.txt` |
| Rust standard library and runtime (inside the clipboard library) | `super_native_extensions.dll` | MIT or Apache 2.0, with incorporated components | `third_party_licenses/rust-stdlib-NOTICES.html` and `third_party_licenses/rust-runtime-LICENSES.txt` |
| Dart JNI native asset | `dartjni.dll` | BSD 3-Clause | `third_party_licenses/jni-LICENSE` |
| File selector and URL launcher plugins | `file_selector_windows_plugin.dll`, `url_launcher_windows_plugin.dll` | BSD 3-Clause | `third_party_licenses/` |
| Material icons font | `data/flutter_assets/fonts/` | Apache 2.0 | `data/flutter_assets/NOTICES.Z` |

The Rust notice files are a conservative superset: they include texts for
platforms and tools that are not part of this Windows build.

## Not included

This package contains no media player library. It does not include libmpv,
FFmpeg, or separate ANGLE graphics libraries. Audio and Movie attachments open
in the player Windows associates with them.

The Microsoft Visual C++ runtime is not bundled. It is a prerequisite that you
install from Microsoft; see INSTALL.md.

## Where the PDFium binary comes from

The PDFium binary is the published
[pdfium-binaries build chromium/8125](https://github.com/bblanchon/pdfium-binaries/releases/tag/chromium%2F8125).
The build pins that archive by SHA-256 and checks every package file before
compiling. `provenance.json` records the archive address and hashes.

## Source access for colored 2.1.0 (MPL 2.0)

The native clipboard library's default logger depends on colored 2.1.0, which
is licensed under the
[Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/). Its exact
upstream source is available as
[colored 2.1.0](https://static.crates.io/crates/colored/colored-2.1.0.crate).
Archive SHA-256:
`cbf2150cce219b664a8a70df7a1f933836724b503f8a413af9365b4dcc4d90b8`.
Vasmim does not modify it. Its MPL licence text is in
`third_party_licenses/clipboard-NOTICES.txt`. Recipients keep their MPL rights
to those source files.

## Source for everything else

Vasmim's own source code, its exact dependency versions (`pubspec.lock`), and
its build instructions are published at <https://github.com/racasan/vasmim>.
The native clipboard library is the prebuilt binary published by its authors
for the pinned `super_native_extensions` release; it was not rebuilt for
Vasmim.
