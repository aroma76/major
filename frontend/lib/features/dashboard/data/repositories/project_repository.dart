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

  /// Returns a single project with its full task list and members.
  Future<Map<String, dynamic>> getProject(int id) async {
    final response = await _api.getProject(id);
    return response.data as Map<String, dynamic>;
  }

  /// Creates a new Kanban project.
  Future<void> createProject(Map<String, dynamic> data) async {
    await _api.createProject(data);
  }

  /// Returns students from the same classroom who can be added to [projectId].
  Future<List<Map<String, dynamic>>> getClassroomStudents(int projectId) async {
    final response = await _api.getProjectStudents(projectId);
    final data = response.data as Map<String, dynamic>;
    final list = data['students'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Adds a student (by [userId]) to [projectId].
  Future<Map<String, dynamic>> addMember(int projectId, int userId) async {
    final response = await _api.addProjectMember(projectId, userId);
    final data = response.data as Map<String, dynamic>;
    return data['member'] as Map<String, dynamic>? ?? {};
  }

  /// Removes [userId] from [projectId].
  Future<void> removeMember(int projectId, int userId) async {
    await _api.removeProjectMember(projectId, userId);
  }

  /// Deletes a project by [id].
  Future<void> deleteProject(int id) async {
    await _api.deleteProject(id);
  }

  /// Creates a task inside [projectId].
  Future<void> createTask(int projectId, Map<String, dynamic> data) async {
    await _api.createProjectTask(projectId, data);
  }

  /// Fully updates [taskId] inside [projectId].
  Future<void> updateTask(
      int projectId, int taskId, Map<String, dynamic> data) async {
    await _api.updateProjectTask(projectId, taskId, data);
  }

  /// Updates the status of [taskId] inside [projectId].
  Future<void> updateTaskStatus(
      int projectId, int taskId, String status) async {
    await _api.updateProjectTaskStatus(projectId, taskId, status);
  }

  /// Permanently deletes [taskId] from [projectId].
  Future<void> deleteTask(int projectId, int taskId) async {
    await _api.deleteProjectTask(projectId, taskId);
  }
}
