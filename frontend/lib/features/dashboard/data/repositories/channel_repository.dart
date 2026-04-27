import '../../../../core/services/api_service.dart';
import '../models/channel_model.dart';

/// Handles all subject/channel data fetching and parsing.
class ChannelRepository {
  final _api = ApiService();

  /// Returns the list of channels the current user is enrolled in.
  Future<List<ChannelModel>> getMyChannels() async {
    final response = await _api.getChannels();
    final data = response.data as Map<String, dynamic>;
    final list = data['channels'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single channel by [id].
  Future<ChannelModel> getChannelById(int id) async {
    final response = await _api.getChannelById(id);
    final data = response.data as Map<String, dynamic>;
    return ChannelModel.fromJson(data['channel'] as Map<String, dynamic>);
  }
}
