# 📄 `repositories/channel_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/channel_repository.dart`
**Role:** Data access layer for subject channels — wraps `ApiService` calls and returns typed `ChannelModel` objects.

---

## 1. What is the Repository Pattern?

The **Repository Pattern** separates **data access logic** from **business logic**:
```
Widget / Provider
    │ calls
    ▼
ChannelRepository    ← This file
    │ calls
    ▼
ApiService (Dio HTTP client)
    │ calls
    ▼
Backend REST API
```

---

## 2. `getMyChannels()`

```dart
class ChannelRepository {
  final _api = ApiService();

  Future<List<ChannelModel>> getMyChannels() async {
    final response = await _api.getChannels();
    final data = response.data as Map<String, dynamic>;
    final list = data['channels'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChannelModel> getChannelById(int id) async {
    final response = await _api.getChannelById(id);
    final data = response.data as Map<String, dynamic>;
    return ChannelModel.fromJson(data['channel'] as Map<String, dynamic>);
  }
}
```

| Line | What It Does |
|---|---|
| `await _api.getChannels()` | Makes GET `/api/channels` with auth token |
| `response.data as Map<...>` | Casts Dio response to a typed Map |
| `data['channels'] as List<dynamic>? ?? []` | Extracts the `channels` array; falls back to empty list if key is absent |
| `.map((e) => ChannelModel.fromJson(...))` | Converts each raw JSON map to a typed `ChannelModel` |
| `.toList()` | Materializes the lazy Iterable into a `List` |

**Why `?? []`?** If the API returns `{ "channels": null }` or the key is missing, the app shows an empty list instead of crashing.

---

## 3. Frontend Connection

```dart
// In api_providers.dart:
final _channelRepo = ChannelRepository();

final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  ref.keepAlive();
  return _channelRepo.getMyChannels();
});
```

---

## 4. Final Summary

`channel_repository.dart` is the thinnest repository — two methods that parse API responses into typed `ChannelModel` lists. Its `channelId` is passed as a parameter to virtually every other provider in the app.
