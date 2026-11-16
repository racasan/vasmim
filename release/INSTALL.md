# Install, update, and remove Vasmim

## Requirements

- Windows x64. Vasmim was developed and tested on Windows 10; Windows 11 is
  expected to work but has had less testing. ARM64 and 32-bit Windows are not
  supported targets.
- Install the Microsoft Visual C++ 2015–2022 x64 Redistributable if it is not
  already present. Obtain it from [Microsoft's official download page](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
- No Flutter SDK, Dart SDK, Visual Studio, Python, or Java installation is
  required for the Windows application.

## Run the ZIP edition

1. Download the Windows x64 ZIP and adjacent SHA-256 checksum from the same
   official release page.
2. In PowerShell, run `Get-FileHash -Algorithm SHA256 -LiteralPath '.\download.zip'`
   using the actual ZIP filename. Compare with the checksum file.
3. Extract the complete ZIP into a normal folder. Keep every DLL and the `data`
   directory beside `vasmim.exe`. Do not run it from inside the ZIP.
4. Run `vasmim.exe`. A second launch brings you back to the existing instance
   where possible; only one instance per Windows user may run.
5. Create a disposable Board, write a Note, wait for Saved, close and reopen.

This build is unsigned. Windows may display an unknown-publisher
warning. Verify the source and checksum; do not disable Windows security tools.
If Windows reports missing `VCRUNTIME140` or `MSVCP140`, install the Microsoft
runtime above. For other launch failures, use the bug-reporting guide.

## Where work is stored

The Library is in your Windows roaming application-data area, normally
`%APPDATA%\Vasmim Project\vasmim`. Use a Board's **Find in Explorer** command
to locate its exact managed folder. A Library project folder organizes Boards
inside the app; it does not choose their Windows storage location.

Boards contain `board.json`, managed `assets`, and a previous saved JSON copy
when available. Those internal recovery files are not a replacement for
**Export all boards** and **Verify backup folder**. A recovered previous copy
may lack the newest edits; Vasmim shows a recovery notice. An unreadable primary
is preserved when you subsequently save the recovered Board.

## Update

Export and verify a backup first. Close Vasmim, extract the new bundle into a
separate folder, and run the new executable. Do not mix DLLs from different
versions. Keep your backup until reopen, attachment, and editing checks succeed.
Do not open newer-format Boards in an older release unless compatibility is
explicitly documented.

## Remove

Close Vasmim and remove its extracted program folder. This does not remove the
Library. Preserve or export your Boards before deliberately removing their
application-data folder. Board deletion inside Vasmim permanently removes its
managed content and does not go through the Windows Recycle Bin.

PDFs have an in-app viewer. Audio, movies, and Word/Excel files open in the
application Windows associates with them. YouTube and other web links use your
browser/application and need network access. Read PRIVACY.md for automatic
thumbnail/icon requests.
