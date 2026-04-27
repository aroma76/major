import '../../../../core/services/api_service.dart';

/// Handles announcement fetching and creation per channel.
class AnnouncementRepository {
  final _api = ApiService();

  /// Returns all announcements for [channelId].
  Future<List<Map<String, dynamic>>> getAnnouncements(int channelId) async {
    final response = await _api.getAnnouncements(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['announcements'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
