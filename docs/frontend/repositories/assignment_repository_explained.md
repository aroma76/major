# 📄 `repositories/assignment_repository.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/data/repositories/assignment_repository.dart`
**Role:** Data access for assignments — supports single-channel and parallel multi-channel fetching with per-channel error isolation.

---

## 1. Source Code

```dart
class AssignmentRepository {
  final _api = ApiService();

  Future<List<AssignmentModel>> getAssignments(int channelId) async {
    final response = await _api.getAssignments(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['assignments'] as List<dynamic>? ?? [];
    return list.map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Aggregates assignments across all [channelIds] in PARALLEL.
  Future<List<AssignmentModel>> getAllAssignments(List<int> channelIds) async {
    final results = await Future.wait(
      channelIds.map(
          (id) => getAssignments(id).catchError((_) => <AssignmentModel>[])),
    );
    return results.expand((list) => list).toList();
  }

  Future<void> submitAssignment(
      int channelId, int assignmentId, FormData formData) async {
    await _api.submitAssignment(channelId, assignmentId, formData);
  }
}
```

---

## 2. `getAllAssignments()` — Parallel Fetching Deep-Dive

```dart
final results = await Future.wait(
  channelIds.map((id) => getAssignments(id).catchError((_) => <AssignmentModel>[])),
);
```

- `channelIds.map(...)` — Creates one future per channel.
- `Future.wait([...])` — Runs ALL futures **concurrently** (not sequentially). If a student has 8 subjects, all 8 API calls happen at the same time.
- `.catchError((_) => <AssignmentModel>[])` — If one channel's assignment fetch fails, it returns an empty list instead of failing ALL channels.
- `results.expand((list) => list).toList()` — Flattens `List<List<AssignmentModel>>` to `List<AssignmentModel>`.

**Performance comparison:**
- Sequential: 8 channels × 200ms = **1600ms** total wait
- Parallel (`Future.wait`): max(200ms) = **~200ms** total wait

**8x performance improvement!**

---

## 3. Final Summary

`assignment_repository.dart` is the most performant repository — its `getAllAssignments` with `Future.wait` + per-channel `catchError` demonstrates production-quality parallel data fetching with fault isolation.
