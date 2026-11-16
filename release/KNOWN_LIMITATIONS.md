# Known limitations

- Windows x64 desktop only. It has been tested on a small number of Windows 10
  machines, not across a full matrix of versions, GPUs, and display scalings.
- Each Board is a fixed 6000 by 4500 units. It is large, not infinite.
- Connectors join Notes and Images. Shapes are visual background elements.
- Project folders are flat in-app organization. Groups do not nest or resize
  their members together. Cross-Board copying excludes Shapes.
- Markdown input supports basic headings, bullets, emphasis, and web links;
  it is not a full Markdown renderer. Notes remain editable app content.
- Circle creation uses an equal-bounds ellipse; free resizing may stretch it.
- Add image preserves GIF animation; clipboard bitmap paste is static.
- Office files are managed references, not editable Office documents in Vasmim.
- YouTube videos open externally. Audio and Movie attachments open in your
  default Windows player; this release has no built-in media player. PDF
  viewing depends on the file; Open externally is available as a fallback.
- Large images are limited to 64 MiB and 40 million pixels. Board JSON and
  portable JSON entries are limited to 32 MiB. Portable Boards allow up to
  10,000 entries, 2 GiB per entry, and 4 GiB total; export reserves space for
  archive overhead. These budgets may reject unusually large projects.
- Boards are not encrypted. Protect your Windows account and independent backups.
- Some automatic network requests occur; see PRIVACY.md.
- Save recovery preserves a previous revision, not every historical edit.
  Forced process termination/power failure cannot save edits still in memory.
- Board deletion is permanent. Export first if uncertain.
- Crowded toolbars at narrow widths remain a usability constraint. Save failures
  now have a separate persistent explanation; test your preferred display scaling.
- No automatic updater, cloud synchronization, collaboration, or account system.
- Provided as is, without warranty or promised support. See the README.
