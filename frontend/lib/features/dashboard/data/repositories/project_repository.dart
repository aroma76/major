import '../../../../core/services/api_service.dart';

/// Handles Kanban project and task data fetching and mutations.
class ProjectRepository {
  final _api = ApiService();

  /// Returns all projects visible to the current user.
  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _api.getProjects();
    final data = response.data as Map<String, dynamic>;
    final list = data['projects'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Returns a single project with its full task list.
  Future<Map<String, dynamic>> getProject(int id) async {
    final response = await _api.getProject(id);
    return response.data as Map<String, dynamic>;
  }

  /// Creates a new Kanban project.
  Future<void> createProject(Map<String, dynamic> data) async {
    await _api.createProject(data);
  }

  /// Updates the custom member names list for [projectId].
  Future<void> updateMembers(int projectId, List<String> names) async {
    await _api.updateProjectMembers(projectId, names);
  }

  /// Deletes a project by [id].
  Future<void> deleteProject(int id) async {
    await _api.deleteProject(id);
  }

  /// Creates a task inside [projectId].
  Future<void> createTask(int projectId, Map<String, dynamic> data) async {
    await _api.createProjectTask(projectId, data);
  }

  /// Updates the status of [taskId] inside [projectId].
  /// [status] must be one of: 'todo', 'in_progress', 'done'.
  Future<void> updateTaskStatus(
      int projectId, int taskId, String status) async {
    await _api.updateProjectTaskStatus(projectId, taskId, status);
  }

  /// Permanently deletes [taskId] from [projectId].
  Future<void> deleteTask(int projectId, int taskId) async {
    await _api.deleteProjectTask(projectId, taskId);
  }
}
