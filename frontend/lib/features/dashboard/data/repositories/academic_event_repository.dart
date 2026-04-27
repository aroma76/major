import '../../../../core/services/api_service.dart';

/// Handles academic calendar event fetching.
class AcademicEventRepository {
  final _api = ApiService();

  /// Returns academic events optionally filtered by [year], [month], or [type].
  Future<List<Map<String, dynamic>>> getEvents({
    int? year,
    int? month,
    String? type,
  }) async {
    final response =
        await _api.getAcademicEvents(year: year, month: month, type: type);
    final data = response.data as Map<String, dynamic>;
    final list = data['events'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
