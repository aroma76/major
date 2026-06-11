import '../../../../core/services/api_service.dart';

/// Handles notes and questions persistence per channel.
class NotesRepository {
  final _api = ApiService();

  /// Fetches all notes of the given [noteType] from [channelId].
  /// [noteType] is either 'note' or 'question'.
  Future<List<Map<String, dynamic>>> getNotes(int channelId,
      {String noteType = 'note'}) async {
    final response = await _api.getNotes(channelId, type: noteType);
    final data = response.data as Map<String, dynamic>;
    final list = data['notes'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Fetches all notes (both types) from [channelId].
  Future<List<Map<String, dynamic>>> getAllNotes(int channelId) async {
    final response = await _api.getNotes(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['notes'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Creates a note/question in [channelId].
  Future<Map<String, dynamic>> createNote(
      int channelId, String title, String content, String noteType) async {
    final response = await _api.createNote(channelId, title, content, noteType);
    final data = response.data as Map<String, dynamic>;
    return data['note'] as Map<String, dynamic>;
  }

  /// Deletes a note by [noteId] from [channelId].
  Future<void> deleteNote(int channelId, int noteId) async {
    await _api.deleteNote(channelId, noteId);
  }
}
