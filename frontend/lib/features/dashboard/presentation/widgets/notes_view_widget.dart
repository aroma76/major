import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../providers/saved_files_provider.dart';
import 'subject_files_view.dart';

class NotesViewWidget extends StatelessWidget {
  const NotesViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubjectFilesView(
      fileType: SavedFileType.note,
      title: 'Notes',
      subtitle: 'Files saved as notes from your subject channels',
      headerIcon: FeatherIcons.bookOpen,
      accentColor: Color(0xFF58A6FF),
      emptyTitle: 'No notes saved yet',
      emptyHint: 'Save files shared in chat as notes\nto find them here, grouped by subject.',
      emptyIcon: FeatherIcons.bookOpen,
    );
  }
}
