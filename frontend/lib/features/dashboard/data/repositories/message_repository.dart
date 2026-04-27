import 'package:dio/dio.dart';
import '../../../../core/services/api_service.dart';
import '../models/api_message_model.dart';

/// Handles all chat message fetching and sending.
class MessageRepository {
  final _api = ApiService();

  /// Returns paginated messages for [channelId].
  /// Pass [cursor] (oldest message id) to load older history.
  Future<List<ApiMessageModel>> getMessages(int channelId,
      {int? cursor, int limit = 50}) async {
    final response =
        await _api.getMessages(channelId, cursor: cursor, limit: limit);
    final data = response.data as Map<String, dynamic>;
    final list = data['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a message (with optional file attachment) to [channelId].
  Future<ApiMessageModel> sendMessage(
      int channelId, FormData formData) async {
    final response = await _api.sendMessage(channelId, formData);
    final data = response.data as Map<String, dynamic>;
    return ApiMessageModel.fromJson(
        data['message'] as Map<String, dynamic>);
  }
}
