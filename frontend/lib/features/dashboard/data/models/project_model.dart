import 'package:flutter/material.dart';

class ProjectModel {
  final String id;
  final String title;
  final List<String> teamMembers;
  final double progress;
  final DateTime deadline;
  final String description;
  final Color color;

  ProjectModel({
    required this.id,
    required this.title,
    required this.teamMembers,
    required this.progress,
    required this.deadline,
    required this.description,
    required this.color,
  });
}
