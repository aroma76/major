import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../data/models/channel_model.dart';
import '../../data/models/assignment_model.dart';
import '../../data/models/api_message_model.dart';

final _api = ApiService();

// ── Channels (Subjects) ───────────────────────────────────────────────────────

final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  final response = await _api.getChannels();
  final data = response.data as Map<String, dynamic>;
  final list = data['channels'] as List<dynamic>? ?? [];
  return list
      .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Assignments (all channels aggregated) ─────────────────────────────────────

final allAssignmentsProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  final channels = await ref.watch(channelsProvider.future);
  final results = <AssignmentModel>[];
  for (final ch in channels) {
    try {
      final response = await _api.getAssignments(ch.id);
      final data = response.data as Map<String, dynamic>;
      final list = data['assignments'] as List<dynamic>? ?? [];
      results.addAll(list.map(
          (e) => AssignmentModel.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }
  return results;
});

// ── Per-Channel Assignments ───────────────────────────────────────────────────

final channelAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, int>((ref, channelId) async {
  final response = await _api.getAssignments(channelId);
  final data = response.data as Map<String, dynamic>;
  final list = data['assignments'] as List<dynamic>? ?? [];
  return list
      .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Per-Channel Messages ──────────────────────────────────────────────────────

final channelMessagesProvider =
    FutureProvider.family<List<ApiMessageModel>, int>((ref, channelId) async {
  final response = await _api.getMessages(channelId);
  final data = response.data as Map<String, dynamic>;
  final list = data['messages'] as List<dynamic>? ?? [];
  return list
      .map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Announcements ─────────────────────────────────────────────────────────────

final channelAnnouncementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, channelId) async {
  final response = await _api.getAnnouncements(channelId);
  final data = response.data as Map<String, dynamic>;
  final list = data['announcements'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ── Notifications ─────────────────────────────────────────────────────────────

final apiNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await _api.getNotifications();
  final data = response.data as Map<String, dynamic>;
  final list = data['notifications'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ── Selected channel for Messages view ────────────────────────────────────────

final selectedChannelProvider =
    StateProvider<ChannelModel?>((ref) => null);

// ── Projects ──────────────────────────────────────────────────────────────────

final projectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await _api.getProjects();
  final data = response.data as Map<String, dynamic>;
  final list = data['projects'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});

