# 📄 `models/api_message_model.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/models/api_message_model.dart`
**Lines:** 71
**Role:** Dart data class representing a single chat message from the API.

---

## 1. File Purpose

`ApiMessageModel` is the **typed data contract** between the backend's message JSON and Flutter's UI. It:
- Maps raw JSON keys (`sender_id`, `created_at`) to Dart-style camelCase fields (`senderId`, `createdAt`)
- Handles nullable fields gracefully (a message can be text-only or file-only)
- Supports thread replies via `parentId`, `parentContent`, `parentSenderName`
- Provides `toJson()` for local caching (written to `SharedPreferences`)

> **Beginner Analogy:** The backend sends a message as a plain envelope with text written on it. `ApiMessageModel` is the official envelope specification — it tells you exactly which information goes where and what format each piece of information should be in.

---

## 2. Fields Explained

```dart
final int id;                    // Unique message ID (DB primary key)
final int channelId;             // Which channel/subject this belongs to
final int senderId;              // User ID of the message author
final String senderName;         // Author's full name (denormalized JOIN from DB)
final String senderRole;         // 'student', 'faculty', or 'admin'
final String? senderAvatar;      // Public Supabase URL for profile photo (nullable)
final String? content;           // Text content (null for file-only messages)
final String? fileUrl;           // Supabase file URL (null for text-only messages)
final String? fileName;          // Original filename (null for text-only messages)
final bool isPinned;             // Whether faculty/admin pinned this message
final DateTime createdAt;        // Message timestamp
final int? parentId;             // ID of replied-to message (null if not a reply)
final String? parentContent;     // Content snippet of replied-to message
final String? parentSenderName;  // Author name of replied-to message
```

**Key Design Decisions:**
- `content` and `fileUrl` are both nullable — a message is valid if it has EITHER one.
- `senderName` and `senderRole` are stored directly on the model (denormalized) for performance.
- `parentId`, `parentContent`, `parentSenderName` form a "thread preview" pattern.

---

## 3. `fromJson` Factory — Line-by-Line

```dart
factory ApiMessageModel.fromJson(Map<String, dynamic> json) {
  return ApiMessageModel(
    id: json['id'] as int,
    channelId: json['channel_id'] as int,
    senderId: json['sender_id'] as int,
    senderName: json['sender_name'] as String? ?? 'Unknown',
    senderRole: json['sender_role'] as String? ?? 'student',
    senderAvatar: json['sender_avatar'] as String?,
    content: json['content'] as String?,
    fileUrl: json['file_url'] as String?,
    fileName: json['file_name'] as String?,
    isPinned: json['is_pinned'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    parentId: json['parent_id'] as int?,
    parentContent: json['parent_content'] as String?,
    parentSenderName: json['parent_sender_name'] as String?,
  );
}
```

| Pattern | Example | Why |
|---|---|---|
| `as String? ?? 'Unknown'` | `senderName` | API could return null if user was deleted; fallback keeps UI intact |
| `as bool? ?? false` | `isPinned` | Boolean fields default to false if absent |
| `DateTime.tryParse(...) ?? DateTime.now()` | `createdAt` | Gracefully handles malformed date strings |
| `as String?` | `content`, `fileUrl` | Null-safe — nullable in Dart matches nullable in DB |

---

## 4. `toJson()` — Serialization for Cache

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'channel_id': channelId,
  'sender_id': senderId,
  'sender_name': senderName,
  // ... all fields
  'created_at': createdAt.toIso8601String(),
};
```

- Used by `MessagesNotifier` to serialize messages to `SharedPreferences` cache.
- `createdAt.toIso8601String()` — Converts DateTime to string format for JSON storage.
- Symmetric with `fromJson` — write and read paths use the same keys.

---

## 5. Final Summary

`ApiMessageModel` is the most field-rich model in the project. The defensive nullable casting pattern (`as Type? ?? default`) makes it resilient to backend API changes. The `toJson()` symmetry with `fromJson` enables offline caching without data loss.
