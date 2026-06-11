import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/assignment_model.dart';
import '../../../../core/services/api_service.dart';

import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';

import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/academic_event_repository.dart';

// ── Repository singletons (accessible across providers) ───────────────────────

final _channelRepo = ChannelRepository();
final _assignmentRepo = AssignmentRepository();
final _notesRepo = NotesRepository();
final _announcementRepo = AnnouncementRepository();
final _notificationRepo = NotificationRepository();
final _projectRepo = ProjectRepository();
final _eventRepo = AcademicEventRepository();

// ── Channels (Subjects) ───────────────────────────────────────────────────────

final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  ref.keepAlive(); // persist for the session — channels don't change often
  return _channelRepo.getMyChannels();
});

// ── Assignments (all channels aggregated) ─────────────────────────────────────

final allAssignmentsProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  ref.keepAlive(); // persist — avoids re-fetching all channels on every tab switch
  final channels = await ref.watch(channelsProvider.future);
  return _assignmentRepo.getAllAssignments(channels.map((c) => c.id).toList());
});

// ── Per-Channel Assignments ───────────────────────────────────────────────────

final channelAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, int>((ref, channelId) async {
  return _assignmentRepo.getAssignments(channelId);
});

// channelMessagesProvider removed — use messagesNotifierProvider instead (supports socket + pagination)

// ── Announcements ─────────────────────────────────────────────────────────────

final channelAnnouncementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, channelId) async {
  return _announcementRepo.getAnnouncements(channelId);
});

// ── Notifications (real API) ──────────────────────────────────────────────────

final notificationsApiProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.keepAlive(); // don't re-fetch on every notification panel open
  return _notificationRepo.getNotifications();
});

// ── Selected channel for Messages view ────────────────────────────────────────

class _SelectedChannelNotifier extends Notifier<ChannelModel?> {
  @override
  ChannelModel? build() => null;
  void select(ChannelModel? ch) => state = ch;
}

final selectedChannelProvider =
    NotifierProvider<_SelectedChannelNotifier, ChannelModel?>(
  _SelectedChannelNotifier.new,
);

// ── Projects ──────────────────────────────────────────────────────────────────

final projectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return _projectRepo.getProjects();
});

// ── Notes (per-channel, type-filtered) ────────────────────────────────────────

/// Param: (channelId, noteType) — noteType is 'note' or 'question'
final channelNotesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (int, String)>(
        (ref, key) async {
  final channelId = key.$1;
  final noteType = key.$2;
  return _notesRepo.getNotes(channelId, noteType: noteType);
});

/// Aggregates notes of a given type from ALL enrolled channels.
final allNotesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, noteType) async {
  final channels = await ref.watch(channelsProvider.future);
  final results = await Future.wait(
    channels.map((ch) =>
        _notesRepo.getNotes(ch.id, noteType: noteType).catchError((_) => <Map<String, dynamic>>[]))
  );
  return results.expand((list) => list).toList()
    ..sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate); // newest first
    });
});

// ── Academic Events (Calendar) ────────────────────────────────────────────────

final academicEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, year) async {
  return _eventRepo.getEvents(year: year);
});

// ── Teacher Stats (real API) ────────────────────────────────────────────────

final teacherStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive(); // Expensive query — cache for the session
  final api = ApiService();
  final res = await api.getTeacherStats();
  final data = res.data as Map<String, dynamic>;
  return data['stats'] as Map<String, dynamic>? ?? {};
});

// ── Unified Dashboard Recent Activity ───────────────────────────────────────
// Pass isFaculty = true for teachers, false for students.
// Using family avoids a circular import with auth_provider.dart.

final dashboardRecentActivityProvider =
    FutureProvider.family<Map<String, dynamic>, bool>((ref, isFaculty) async {
  final api = ApiService();
  try {
    final res = isFaculty
        ? await api.getTeacherRecentActivity()
        : await api.getStudentRecentActivity();
    final data = res.data as Map<String, dynamic>;
    final result = {
      'announcements': (data['announcements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      'recentMessages': (data['recentMessages'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    };
    // Only keep alive after a successful fetch — errors remain disposable
    // so ref.invalidate() from the Retry button works correctly.
    ref.keepAlive();
    return result;
  } catch (e) {
    rethrow;
  }
});
