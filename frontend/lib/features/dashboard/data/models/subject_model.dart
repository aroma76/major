import 'package:flutter/material.dart';

class SubjectModel {
  final String id;
  final String name;
  final String teacher;
  final double progress;
  final int pendingTasks;
  final String lastUpdated;
  final String imageUrl;
  final Color color;

  SubjectModel({
    required this.id,
    required this.name,
    required this.teacher,
    required this.progress,
    required this.pendingTasks,
    required this.lastUpdated,
    required this.imageUrl,
    required this.color,
  });
}
