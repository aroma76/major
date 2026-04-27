import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/assignment_model.dart';

import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/assignment_repository.dart';

import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/academic_event_repository.dart';

// ── Repository singletons (accessible across providers) ───────────────────────

final _channelRepo      = ChannelRepository();
final _assignmentRepo   = AssignmentRepository();
final _announcementRepo = AnnouncementRepository();
final _notificationRepo = NotificationRepository();
final _projectRepo      = ProjectRepository();
final _eventRepo        = AcademicEventRepository();

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

// ── Academic Events (Calendar) ────────────────────────────────────────────────

final academicEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, year) async {
  return _eventRepo.getEvents(year: year);
});
