import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SavedFileType { note, questionPaper }

class SavedFile {
  final String id; // message id as string — unique per save
  final int channelId;
  final String subjectName;
  final String fileName;
  final String fileUrl;
  final SavedFileType type;
  final String sharedBy;
  final DateTime savedAt;

  const SavedFile({
    required this.id,
    required this.channelId,
    required this.subjectName,
    required this.fileName,
    required this.fileUrl,
    required this.type,
    required this.sharedBy,
    required this.savedAt,
  });
}

// ── Provider ─────────────────────────────────────────────────────────────────

final savedFilesProvider =
    NotifierProvider<SavedFilesNotifier, List<SavedFile>>(
        SavedFilesNotifier.new);

class SavedFilesNotifier extends Notifier<List<SavedFile>> {
  @override
  List<SavedFile> build() => [];

  String _key(String msgId, SavedFileType type) => '${msgId}_${type.name}';

  bool isSaved(String msgId, SavedFileType type) =>
      state.any((f) => f.id == _key(msgId, type));

  void save({
    required String msgId,
    required int channelId,
    required String subjectName,
    required String fileName,
    required String fileUrl,
    required SavedFileType type,
    required String sharedBy,
  }) {
    final key = _key(msgId, type);
    if (isSaved(msgId, type)) return; // already saved
    state = [
      ...state,
      SavedFile(
        id: key,
        channelId: channelId,
        subjectName: subjectName,
        fileName: fileName,
        fileUrl: fileUrl,
        type: type,
        sharedBy: sharedBy,
        savedAt: DateTime.now(),
      ),
    ];
  }

  void remove(String id) => state = state.where((f) => f.id != id).toList();

  List<SavedFile> byType(SavedFileType type) =>
      state.where((f) => f.type == type).toList();

  /// Returns files of [type] grouped by subjectName.
  Map<String, List<SavedFile>> groupedBySubject(SavedFileType type) {
    final files = byType(type);
    final map = <String, List<SavedFile>>{};
    for (final f in files) {
      map.putIfAbsent(f.subjectName, () => []).add(f);
    }
    return map;
  }
}
