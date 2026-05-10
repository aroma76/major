import 'package:dio/dio.dart';
import '../../../../core/services/api_service.dart';
import '../models/assignment_model.dart';

/// Handles all assignment and submission data fetching and parsing.
class AssignmentRepository {
  final _api = ApiService();

  /// Returns all assignments for a specific [channelId].
  Future<List<AssignmentModel>> getAssignments(int channelId) async {
    final response = await _api.getAssignments(channelId);
    final data = response.data as Map<String, dynamic>;
    final list = data['assignments'] as List<dynamic>? ?? [];
    return list
        .map((e) => AssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aggregates assignments across all [channelIds] in parallel.
  Future<List<AssignmentModel>> getAllAssignments(List<int> channelIds) async {
    final results = await Future.wait(
      channelIds.map(
          (id) => getAssignments(id).catchError((_) => <AssignmentModel>[])),
    );
    return results.expand((list) => list).toList();
  }

  /// Submits a student assignment file for [assignmentId] in [channelId].
  Future<void> submitAssignment(
      int channelId, int assignmentId, FormData formData) async {
    await _api.submitAssignment(channelId, assignmentId, formData);
  }
}
