# 📄 `widgets/subject_files_view.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/subject_files_view.dart`
**Lines:** 728
**Role:** Reusable, subject-grouped file browser for Notes and Question Papers — with collapsible subject groups, file-type icons, hover-reveal actions (open/download/remove), and platform-aware file opening.

---

## 1. File Purpose

`SubjectFilesView` is a generic, parameterized view used by both `NotesViewWidget` and `QuestionPapersViewWidget`. It renders files from `savedFilesProvider` grouped by subject, with per-file open/download/remove actions.

---

## 2. Provider Dual-Watch Pattern

```dart
final grouped = ref.watch(savedFilesProvider.notifier).groupedBySubject(widget.fileType);
ref.watch(savedFilesProvider); // Re-build when provider state changes
```

**Why watch twice?** `groupedBySubject()` is a **method on the notifier** (not a stream). It's called once for the initial value. The second `ref.watch(savedFilesProvider)` forces a rebuild whenever the provider's state list changes — triggering a re-call of `groupedBySubject()`.

This pattern is necessary when you need computed data from the notifier but also need reactive rebuilds.

---

## 3. `_SubjectGroup` — Collapsible Section

```dart
bool _expanded = true; // Default: expanded

AnimatedCrossFade(
  crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
  firstChild: Column(children: [...files.map(...)]),
  secondChild: const SizedBox.shrink(),
),
```

**`AnimatedRotation`** on the chevron arrow:
```dart
AnimatedRotation(
  turns: _expanded ? 0 : -0.25,  // 0 = 0°, -0.25 = -90° (pointing right)
  duration: const Duration(milliseconds: 200),
)
```
`turns` is a fraction of a full rotation. `-0.25` = -90° = pointing right (collapsed). `0` = pointing down (expanded).

---

## 4. `_openFile()` — Platform-Aware PDF Handling

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

**PDF problem:** Chrome's built-in viewer sometimes fails to render Cloudinary-served PDFs (CORS issues, incorrect MIME types). The fix: route PDFs through Google Docs Viewer (`docs.google.com/viewer?url=...`), which fetches and renders the PDF server-side.

**`url.split('.').last.split('?').first`** — Strips query parameters before extracting the extension. Example: `file.pdf?token=abc` → `pdf`.

**`kIsWeb`** — Flutter constant, `true` when running in browser. Allows different file-opening strategies per platform.

---

## 5. `_downloadFile()` — Storage Service Detection

```dart
void _downloadFile() {
  final cleanUrl = widget.file.fileUrl.split('?').first;
  if (kIsWeb) {
    if (cleanUrl.contains('supabase.co')) {
      html.window.open('$cleanUrl?download=true', '_blank');
    } else {
      // Legacy Cloudinary URL: backend proxy
      final token = html.window.localStorage['flutter.adtu_token'] ?? '';
      final encoded = Uri.encodeComponent(cleanUrl);
      html.window.open(
        '${AppConfig.apiUrl}/file-proxy?url=$encoded&token=${Uri.encodeComponent(token)}',
        '_blank',
      );
    }
  }
}
```

**Two download strategies:**
1. **Supabase files:** Append `?download=true` to the URL. Supabase Storage recognizes this query parameter and sets `Content-Disposition: attachment` header.
2. **Cloudinary (legacy) files:** CORS prevents browser-side download. Route through the backend `GET /file-proxy?url=...&token=...` which proxies the download. The token is read from `localStorage` (where `ApiService` stores the JWT).

---

## 6. File Extension → Icon Mapping

```dart
static IconData _iconForFile(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return FeatherIcons.image;
  if (ext == 'pdf') return FeatherIcons.fileText;
  if (['doc', 'docx'].contains(ext)) return FeatherIcons.file;
  if (['ppt', 'pptx'].contains(ext)) return FeatherIcons.monitor;
  if (['xls', 'xlsx'].contains(ext)) return FeatherIcons.grid;
  return FeatherIcons.paperclip;  // Default
}
```

Deterministic icon based on file extension. Desktop and mobile layouts both define this method — a minor code duplication that could be extracted to a utility function.

---

## 7. Final Summary

`SubjectFilesView` is the most platform-aware widget in the project, handling PDF/image open logic and Supabase/Cloudinary download differences. The dual-provider-watch pattern, collapsible groups, and hover-reveal action buttons make it a robust file management UI.

---

# 📄 `widgets/subject_hub_widget.dart` — Complete Explanation

**File Path:** `frontend/lib/.../widgets/subject_hub_widget.dart`
**Lines:** 761
**Role:** Per-subject bottom sheet with 4 tabs: Overview (stats + info + upcoming), Assignments (channel-specific), Announcements (channel-specific), and Chat shortcut.

---

## 1. File Purpose

`SubjectHubSheet` opens when the user taps a subject card in `SubjectsViewWidget`. It provides a comprehensive subject dashboard via a 4-tab interface without leaving the main screen.

---

## 2. Bottom Sheet Height

```dart
height: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.88),
```

- Mobile: 92% of screen height (near fullscreen)
- Desktop: 88% of screen height (leaves a sliver at top)

This is fixed-height, not a `DraggableScrollableSheet`. Simpler but less flexible.

---

## 3. `_openChat()` — Cross-Navigation Pattern

```dart
void _openChat() {
  Navigator.pop(context);                              // Close the hub sheet
  ref.read(selectedChannelProvider.notifier).select(widget.channel);  // Pre-select channel
  ref.read(navigationProvider.notifier).navigateTo(4); // Navigate to Messages (index 4)
}
```

This three-step navigation:
1. Closes the bottom sheet
2. Sets `selectedChannelProvider` so the Messages view knows which channel to open
3. Navigates the sidebar to the Messages tab

The chat tab in the hub is just a shortcut button that triggers this flow.

---

## 4. Per-Channel Family Providers

```dart
// Overview tab
final assignAsync = ref.watch(channelAssignmentsProvider(channel.id));

// Assignments tab
final async = ref.watch(channelAssignmentsProvider(channelId));

// Announcements tab
final async = ref.watch(channelAnnouncementsProvider(channelId));
```

Both `channelAssignmentsProvider` and `channelAnnouncementsProvider` are family providers — each `channel.id` creates a separate cached instance. Opening different subject hubs loads data independently.

---

## 5. Assignment Status Color Logic

```dart
final statusColor = a.isSubmitted
    ? const Color(0xFF3FB950)   // Green
    : a.isOverdue
        ? Colors.red
        : const Color(0xFFD29922); // Yellow
final statusLabel = a.isSubmitted ? 'Submitted' : a.isOverdue ? 'Overdue' : 'Pending';
```

Status is determined by `AssignmentModel.isSubmitted` and `AssignmentModel.isOverdue` (computed properties in the model). The ternary chain has implicit priority: submitted > overdue > pending.

---

## 6. Overview Tab — Stats Chips

```dart
final pending = assignments.where((a) => !a.isSubmitted && !a.isOverdue).length;
final overdue = assignments.where((a) => a.isOverdue).length;
final submitted = assignments.where((a) => a.isSubmitted).length;
```

Three `_StatChip` widgets in a `Row` (each `Expanded`) showing pending/overdue/done counts.

**`!a.isSubmitted && !a.isOverdue`** — An assignment is "pending" only if it's neither submitted nor past deadline.

---

## 7. Drag Handle

```dart
Center(
  child: Container(
    margin: const EdgeInsets.only(top: 12),
    width: 40, height: 4,
    decoration: BoxDecoration(color: AppColors.getBorderColor(context), borderRadius: BorderRadius.circular(2)),
  ),
),
```

Standard iOS-style drag handle — a 40×4 rounded rectangle at the top. Even though this sheet isn't `DraggableScrollableSheet`, the handle is present for visual convention (users expect it).

---

## 8. Final Summary

`SubjectHubSheet` is a comprehensive per-subject mini-dashboard. The `_openChat()` three-step cross-navigation (pop → select channel → navigate) is the most complex inter-widget interaction in the project. Family providers ensure each channel's data is cached independently, making repeated open/close operations near-instant.
