import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = StorageService();
  late final Dio dio;

  void init() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 30), // covers Render cold start (~20-30s)
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Inject JWT token on every request
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read('adtu_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // You can add global 401 logout handling here
        return handler.next(e);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Response> login(String rollNumber, String dob) =>
      dio.post('/auth/login', data: {'identifier': rollNumber, 'password': dob});

  Future<Response> signup(Map<String, dynamic> data) =>
      dio.post('/auth/register', data: data);

  Future<Response> getMe() => dio.get('/auth/me');

  // ── Channels (Subjects) ───────────────────────────────────────────────────
  Future<Response> getChannels() => dio.get('/channels');

  Future<Response> getChannelById(int id) => dio.get('/channels/$id');

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<Response> getMessages(int channelId, {int? cursor, int limit = 50}) =>
      dio.get('/channels/$channelId/messages', queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      });

  Future<Response> sendMessage(int channelId, FormData formData) =>
      dio.post('/channels/$channelId/messages',
          data: formData,
          options: Options(contentType: 'multipart/form-data'));

  // ── Assignments ───────────────────────────────────────────────────────────
  Future<Response> getAssignments(int channelId) =>
      dio.get('/channels/$channelId/assignments');

  Future<Response> submitAssignment(int channelId, int assignmentId, FormData formData) =>
      dio.post('/channels/$channelId/assignments/$assignmentId/submit',
          data: formData,
          options: Options(contentType: 'multipart/form-data'));

  // ── Announcements ─────────────────────────────────────────────────────────
  Future<Response> getAnnouncements(int channelId) =>
      dio.get('/channels/$channelId/announcements');

  // ── Notes ─────────────────────────────────────────────────────────────────
  Future<Response> getNotes(int channelId) =>
      dio.get('/channels/$channelId/notes');

  // ── Files ─────────────────────────────────────────────────────────────────
  Future<Response> getFiles(int channelId) =>
      dio.get('/channels/$channelId/files');

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<Response> getNotifications() => dio.get('/notifications');

  Future<Response> markNotificationRead(int id) =>
      dio.patch('/notifications/$id/read');

  // ── Academic Events / Calendar ─────────────────────────────────────────────
  Future<Response> getAcademicEvents({int? month, int? year, String? type}) {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year  != null) params['year']  = year;
    if (type  != null && type != 'all') params['type'] = type;
    return dio.get('/academic-events', queryParameters: params);
  }

  // ── Assignment Kanban Status ───────────────────────────────────────────────
  Future<Response> updateAssignmentStatus(int channelId, int assignmentId, String status) =>
      dio.patch('/channels/$channelId/assignments/$assignmentId/status',
          data: {'status': status});

  // ── Projects ──────────────────────────────────────────────────────────────────
  Future<Response> getProjects() => dio.get('/projects');

  Future<Response> getProject(int id) => dio.get('/projects/$id');

  Future<Response> createProject(Map<String, dynamic> data) =>
      dio.post('/projects', data: data);

  Future<Response> updateProjectProgress(int id, int progress) =>
      dio.patch('/projects/$id/progress', data: {'progress': progress});

  Future<Response> deleteProject(int id) => dio.delete('/projects/$id');

  Future<Response> createProjectTask(int projectId, Map<String, dynamic> data) =>
      dio.post('/projects/$projectId/tasks', data: data);

  Future<Response> updateProjectTaskStatus(int projectId, int taskId, String status) =>
      dio.patch('/projects/$projectId/tasks/$taskId/status',
          data: {'status': status});
}
