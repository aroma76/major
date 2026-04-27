import '../../../../core/services/api_service.dart';

/// Handles in-app notification fetching and read-status updates.
class NotificationRepository {
  final _api = ApiService();

  /// Returns all notifications for the current user.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _api.getNotifications();
    final data = response.data as Map<String, dynamic>;
    final list = data['notifications'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Marks a single notification as read by [id].
  Future<void> markRead(int id) async {
    await _api.markNotificationRead(id);
  }
}
