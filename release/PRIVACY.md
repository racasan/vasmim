# Privacy and local data

Vasmim keeps Boards and managed copies of imported files in your Windows user
application-data folder. It does not require an application account. No analytics,
advertising, or cloud-sync service is configured in the application source.
Boards and assets are not encrypted by Vasmim. Anyone with access to those
Windows files may be able to read them.

## Network and external applications

- Website Notes can automatically request `/favicon.ico` from the saved website
  host when displayed. HTTP addresses may use unencrypted HTTP. Website hosts
  receive the request and your network address; links can also name local hosts.
- YouTube cards request thumbnails from `i.ytimg.com`. Missing thumbnails may
  be retried when a Board is reopened. Requests reveal the requested video ID
  and network address to that service. Cached thumbnails are stored locally.
- Clicking a web/YouTube link opens your system browser or associated app, whose
  privacy settings and service terms then apply. The saved URL may include
  parameters you originally pasted.
- Opening managed documents externally hands their file path/content to the
  associated application. That application may have its own network behaviour.
- Opening an imported file is not sandboxed. PDFs are parsed by the bundled
  PDFium library; other files are parsed by the application that opens them.
  Treat files from untrusted sources with the same care as anywhere else.

Vasmim therefore should not be described as never accessing the network. There
is currently no application-wide offline toggle. External requests fail with
fallbacks where available; ordinary text/Board editing uses local storage.

## Sharing and reporting

Portable exports include Board content and referenced managed assets. Share only
what you intend others to see. A whole-Board image can reveal more than the
current view. Review output before uploading it.

Problem reports go to the project's public GitHub issue page; see
BUG_REPORTING.md. GitHub processes them under its own terms, and they are
visible to everyone. Reports are sent only when you submit them. Start with
steps, version, and sanitized screenshots. Do not post private Boards,
documents, personal paths, or credentials.

Removing the extracted application does not remove the Library. See INSTALL.md.
