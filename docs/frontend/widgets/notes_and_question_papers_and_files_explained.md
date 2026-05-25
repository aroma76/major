# Word-by-Word Deep Dive: `notes_and_question_papers_and_files_explained.md`

> Covers three interconnected files:
> - `notes_view_widget.dart` (24 lines) — thin wrapper
> - `question_papers_view_widget.dart` (24 lines) — thin wrapper
> - `subject_files_view.dart` (728 lines) — the real implementation shared by both
>
> This explains the **wrapper pattern** for component reuse, expandable subject groups, hover-reveal action buttons, PDF open via Google Docs Viewer, and the download proxy for Cloudinary vs Supabase files.

---

## The Wrapper Pattern (Lines 1–24 of each view)

### `notes_view_widget.dart`

```dart
class NotesViewWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SubjectFilesView(
      fileType: SavedFileType.note,
      title: 'Notes',
      subtitle: 'Files saved as notes from your subject channels',
      headerIcon: FeatherIcons.bookOpen,
      accentColor: Color(0xFF58A6FF),   // blue
      emptyTitle: 'No notes saved yet',
      emptyHint: 'Save files shared in chat as notes\nto find them here, grouped by subject.',
      emptyIcon: FeatherIcons.bookOpen,
    );
  }
}
```

### `question_papers_view_widget.dart`

```dart
class QuestionPapersViewWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SubjectFilesView(
      fileType: SavedFileType.questionPaper,
      title: 'Question Papers',
      accentColor: Color(0xFF238636),   // green
      ...
    );
  }
}
```

**Why this pattern?** — Both screens are IDENTICAL in behavior. Only the `fileType`, color, title, and empty-state text differ. Rather than duplicating 728 lines, one `SubjectFilesView` is configured differently via constructor props.

**The `fileType` enum** (`SavedFileType.note` vs `SavedFileType.questionPaper`) is the filter that determines which saved files are shown.

---

## `subject_files_view.dart` Line 1–2 — Special Imports

```dart
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kIsWeb;
```

**`import 'dart:async' show unawaited`** — `unawaited()` is a Dart function that explicitly marks a `Future` as intentionally not awaited. Without it, calling an `async` function without `await` causes a lint warning. `unawaited(launchUrl(...))` suppresses this warning.

**`show kIsWeb`** — imports ONLY `kIsWeb` from `foundation.dart`. `kIsWeb` is a compile-time constant: `true` when running in a web browser, `false` on mobile/desktop.

---

## Lines 66–120 — `build()` — Two-Provider Watch

```dart
final grouped = ref
    .watch(savedFilesProvider.notifier)
    .groupedBySubject(widget.fileType);

ref.watch(savedFilesProvider);  // Re-build when provider state changes
```

**First line:** Calls `groupedBySubject(fileType)` on the NOTIFIER to group files. This is a synchronous method — no async needed since files are in memory.

**Second line:** `ref.watch(savedFilesProvider)` — subscribes to state changes WITHOUT using the return value. When a file is removed (`ref.read(savedFilesProvider.notifier).remove(id)`), the provider state changes → this `watch` triggers a rebuild → `grouped` is recalculated.

**Why not just watch the notifier?** — `watch(notifier)` only subscribes to notifier instance, not its state changes. `watch(provider)` subscribes to state changes.

---

## Lines 184–193 — File Count Badge

```dart
if (fileCount > 0)
  Container(
    child: Text(
      '$fileCount file${fileCount == 1 ? '' : 's'}',
      // 1 file   →  "1 file"
      // 3 files  →  "3 files"
    ),
  ),
```

**`fileCount == 1 ? '' : 's'`** — conditional pluralization. The `?` ternary: if count is 1, append nothing; otherwise append `'s'`. Simple but correct pluralization without a library.

---

## Lines 230–325 — `_SubjectGroup` — Collapsible Group

```dart
class _SubjectGroupState extends State<_SubjectGroup> {
  bool _expanded = true;   // starts expanded

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(children: [
        // Header row (tap to toggle)
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(children: [
            // colored dot, subject name, file count badge
            AnimatedRotation(
              turns: _expanded ? 0 : -0.25,
              // 0 turns = 0° (chevron down)
              // -0.25 turns = -90° (chevron right, collapsed)
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ]),
        ),

        // File list (animated expand/collapse)
        AnimatedCrossFade(
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(children: [...files]),
          secondChild: const SizedBox.shrink(),
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}
```

**`AnimatedRotation(turns: ...)`** — rotates the chevron icon.

**`turns`** — full rotation units. `0` = 0°, `0.25` = 90°, `0.5` = 180°, `1.0` = 360°.

**`-0.25` = -90°** — rotates the DOWN chevron 90° counter-clockwise → RIGHT-facing chevron = collapsed state.

**`AnimatedCrossFade`** — animates between two children with a cross-fade. Unlike `AnimatedSwitcher`, it always keeps BOTH children in the tree (just animates their opacity). This prevents content from being re-built when expanding again.

**`CrossFadeState.showFirst`** — shows the file list (fully visible).

**`CrossFadeState.showSecond`** — shows `SizedBox.shrink()` (invisible). The file list fades out as the empty box fades in.

---

## Lines 347–382 — `_openFile()` and `_downloadFile()`

### Open File

```dart
void _openFile() {
  final url = widget.file.fileUrl;
  final ext = url.split('.').last.split('?').first.toLowerCase();
  final isPdf = ext == 'pdf';

  if (kIsWeb) {
    final openUrl = isPdf
        ? 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true'
        : url;
    html.window.open(openUrl, '_blank');
  } else {
    unawaited(launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'));
  }
}
```

**`url.split('.').last.split('?').first`** — extracts file extension from URL:
1. `'https://example.com/file.pdf?token=abc'.split('.')` → `['https://example', 'com/file', 'pdf?token=abc']`
2. `.last` → `'pdf?token=abc'`
3. `.split('?').first` → `'pdf'`
4. `.toLowerCase()` → `'pdf'`

**PDF files on web** — wrapped in Google Docs Viewer: `https://docs.google.com/viewer?url=<encoded-url>&embedded=true`. This prevents Chrome's built-in PDF viewer from failing on Cloudinary delivery URLs.

**`Uri.encodeComponent(url)`** — URL-encodes special characters. The Cloudinary URL (with `/`, `?`, `&`) must be encoded to be a valid query parameter value.

**`html.window.open(url, '_blank')`** — opens URL in a new browser tab. `dart:html` is a web-only library.

### Download File

```dart
void _downloadFile() {
  final cleanUrl = widget.file.fileUrl.split('?').first;  // remove query params
  if (kIsWeb) {
    if (cleanUrl.contains('supabase.co')) {
      html.window.open('$cleanUrl?download=true', '_blank');  // Supabase download
    } else {
      // Legacy Cloudinary URL: route through backend proxy
      final token = html.window.localStorage['flutter.adtu_token'] ?? '';
      final encoded = Uri.encodeComponent(cleanUrl);
      html.window.open(
        '${AppConfig.apiUrl}/file-proxy?url=$encoded&token=${Uri.encodeComponent(token)}',
        '_blank',
      );
    }
  } else {
    unawaited(launchUrl(Uri.parse(cleanUrl), webOnlyWindowName: '_blank'));
  }
}
```

**Two storage backends:**
- **Supabase:** `?download=true` forces Supabase to send `Content-Disposition: attachment` header → browser downloads instead of previewing.
- **Cloudinary (legacy):** Files at Cloudinary URLs need authentication via the backend proxy. The token is read from `localStorage` (`flutter.adtu_token`) and sent as a query parameter to the backend `/file-proxy` route, which fetches and forwards the file.

**`html.window.localStorage['flutter.adtu_token']`** — SharedPreferences on web stores values as `flutter.<key>` in the browser's localStorage.

---

## Lines 440–450 — File Icon Mapping

```dart
static IconData _iconForFile(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return FeatherIcons.image;
  if (ext == 'pdf')                                          return FeatherIcons.fileText;
  if (['doc', 'docx'].contains(ext))                        return FeatherIcons.file;
  if (['ppt', 'pptx'].contains(ext))                        return FeatherIcons.monitor;
  if (['xls', 'xlsx'].contains(ext))                        return FeatherIcons.grid;
  return FeatherIcons.paperclip;  // fallback
}
```

**`.contains(ext)`** — checks if the extension is in the list. Cleaner than `ext == 'jpg' || ext == 'jpeg' || ...`.

**Fallback icon (`FeatherIcons.paperclip`)** — unknown file types get a generic attachment icon.

---

## Lines 509–533 — Hover-Reveal Action Buttons

```dart
AnimatedOpacity(
  opacity: hovered ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 180),
  child: Row(children: [
    _ActionBtn(icon: FeatherIcons.externalLink, tooltip: 'Open',     onTap: onOpen),
    _ActionBtn(icon: FeatherIcons.download,     tooltip: 'Download', onTap: onDownload),
    _ActionBtn(icon: FeatherIcons.trash2,       tooltip: 'Remove',   onTap: onRemove, color: Colors.red),
  ]),
),
```

**Desktop only** — action buttons are hidden when not hovered (`opacity: 0.0`). When the mouse enters the file row (`MouseRegion.onEnter`), `_hovered = true` → buttons fade in.

**Mobile** — `_MobileLayout` shows Open + Remove buttons always (no hover needed on touch screens).

---

## Summary

```
NotesViewWidget             QuestionPapersViewWidget
  └─ SubjectFilesView(       └─ SubjectFilesView(
       fileType: note,             fileType: questionPaper,
       accentColor: blue,          accentColor: green,
       ...)                        ...)
              │
              ▼
       SubjectFilesView (ConsumerStatefulWidget)
         ├─ _PageHeader (title, subtitle, file count badge)
         ├─ _EmptyState (if no files) — circular icon + hint + CTA
         └─ ListView of _SubjectGroup
              ├─ Collapsible header (AnimatedRotation chevron, AnimatedCrossFade body)
              └─ _FileCard × N
                   ├─ Desktop: _DesktopLayout (hover-reveal buttons)
                   │   ├─ Open → Google Docs Viewer (PDF) or direct (image)
                   │   ├─ Download → Supabase ?download=true or /file-proxy
                   │   └─ Remove → savedFilesProvider.notifier.remove()
                   └─ Mobile: _MobileLayout (always-visible Open + Remove)
```
