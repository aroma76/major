import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../providers/saved_files_provider.dart';
import 'subject_files_view.dart';

class QuestionPapersViewWidget extends StatelessWidget {
  const QuestionPapersViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubjectFilesView(
      fileType: SavedFileType.questionPaper,
      title: 'Question Papers',
      subtitle: 'Past question papers saved from your subject channels',
      headerIcon: FeatherIcons.fileMinus,
      accentColor: Color(0xFF238636),
      emptyTitle: 'No question papers saved yet',
      emptyHint:
          'Save files shared in chat as question papers\nto find them here, grouped by subject.',
      emptyIcon: FeatherIcons.fileMinus,
    );
  }
}
