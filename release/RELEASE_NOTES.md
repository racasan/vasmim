# Vasmim 0.1.0-beta.2 — first public release

Application version 0.1.0-beta.2+3; Board format 31. Windows x64, portable ZIP.

Vasmim is free software provided as is, without warranty or promised support.
Read INSTALL.md before running it and keep independent backups of your Boards.

## What is in this release

- Notes, Images, Canvas Headings, managed file attachments, YouTube cards,
  Connectors, Groups, Scenes, and background Shapes on fixed 6,000-by-4,500
  Boards, with a searchable Library, project folders, and Light/Dark modes.
- Portable `.vasmim` Board export/import, Export all boards, and backup
  verification. Current-view and whole-Board PNG export and clipboard copy.
- Board saves stage their output and retain a validated previous revision.
  Recovery preserves unreadable primary files when later edits are saved.
- Normal closing waits for pending saves; save failures keep the app open.
- One instance per Windows user, preventing competing Library writers.
- PDF viewing uses pinned PDFium 158.0.8125.0 with package integrity checks and
  its complete bundled third-party notices.

## Changed from the earlier private builds

- Audio and Movie attachments now open in your default Windows player. The
  on-Board Play/Pause/Stop controls and the built-in media viewer are not part
  of this release, and the media and graphics libraries they needed are no
  longer bundled. Existing Boards keep their Audio and Movie cards and files.
- Vasmim's own source code is released under the BSD Zero Clause License.

Board format 31 is unchanged, so Boards from the earlier private builds open
in this release.
