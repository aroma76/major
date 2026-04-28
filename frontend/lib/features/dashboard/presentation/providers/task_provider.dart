import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/project_model.dart';

final taskProvider = NotifierProvider<TaskNotifier, List<TaskModel>>(() {
  return TaskNotifier();
});

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() => SearchQueryNotifier());

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}

final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  if (query.isEmpty) return tasks;

  return tasks.where((task) {
    return task.title.toLowerCase().contains(query) ||
        task.subject.toLowerCase().contains(query) ||
        task.description.toLowerCase().contains(query);
  }).toList();
});

final navigationProvider = NotifierProvider<NavigationNotifier, int>(() => NavigationNotifier());

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void navigateTo(int index) => state = index;
}

enum AssignmentViewType { list, kanban }

final assignmentViewTypeProvider = NotifierProvider<AssignmentViewTypeNotifier, AssignmentViewType>(() => AssignmentViewTypeNotifier());
final selectedSubjectFilterProvider = NotifierProvider<SubjectFilterNotifier, String?>(() => SubjectFilterNotifier());
final selectedPriorityFilterProvider = NotifierProvider<PriorityFilterNotifier, TaskPriority?>(() => PriorityFilterNotifier());

class AssignmentViewTypeNotifier extends Notifier<AssignmentViewType> {
  @override
  AssignmentViewType build() => AssignmentViewType.list;
  void toggle() => state = state == AssignmentViewType.list ? AssignmentViewType.kanban : AssignmentViewType.list;
  void setViewType(AssignmentViewType type) => state = type;
}

class SubjectFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? subject) => state = subject;
}

class PriorityFilterNotifier extends Notifier<TaskPriority?> {
  @override
  TaskPriority? build() => null;
  void set(TaskPriority? priority) => state = priority;
}

class TaskNotifier extends Notifier<List<TaskModel>> {
  @override
  List<TaskModel> build() {
    return _initialTasks;
  }

  // Kanban starts empty — students add their own tasks
  static final List<TaskModel> _initialTasks = [];

  void addTask(TaskModel task) {
    state = [...state, task];
  }

  void updateTaskStatus(String taskId, TaskStatus newStatus) {
    state = [
      for (final task in state)
        if (task.id == taskId) task.copyWith(status: newStatus) else task
    ];
  }

  void removeTask(String taskId) {
    state = state.where((task) => task.id != taskId).toList();
  }
}

final subjectProvider = NotifierProvider<SubjectNotifier, List<SubjectModel>>(() {
  return SubjectNotifier();
});

class SubjectNotifier extends Notifier<List<SubjectModel>> {
  @override
  List<SubjectModel> build() {
    return _initialSubjects;
  }

  static final List<SubjectModel> _initialSubjects = [
    SubjectModel(
      id: 's1',
      name: 'Mobile Development',
      teacher: 'Dr. Sarah Mitchell',
      progress: 0.65,
      pendingTasks: 3,
      lastUpdated: '2 hours ago',
      imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?q=80&w=200&auto=format&fit=crop',
      color: Colors.blue,
    ),
    SubjectModel(
      id: 's2',
      name: 'Database Management',
      teacher: 'Prof. James Wilson',
      progress: 0.40,
      pendingTasks: 5,
      lastUpdated: '1 day ago',
      imageUrl: 'https://images.unsplash.com/photo-1544383835-bda2bc66a55d?q=80&w=200&auto=format&fit=crop',
      color: Colors.orange,
    ),
    SubjectModel(
      id: 's3',
      name: 'Operating Systems',
      teacher: 'Dr. Robert Chen',
      progress: 0.82,
      pendingTasks: 1,
      lastUpdated: '4 hours ago',
      imageUrl: 'https://images.unsplash.com/photo-1629654297299-c8506221ca97?q=80&w=200&auto=format&fit=crop',
      color: Colors.teal,
    ),
    SubjectModel(
      id: 's4',
      name: 'Design & Analysis of Algorithms',
      teacher: 'Prof. Alice Thompson',
      progress: 0.25,
      pendingTasks: 4,
      lastUpdated: 'Just now',
      imageUrl: 'https://images.unsplash.com/photo-1509228468518-180dd482180c?q=80&w=200&auto=format&fit=crop',
      color: Colors.purple,
    ),
  ];
}

final projectProvider = NotifierProvider<ProjectNotifier, List<ProjectModel>>(() {
  return ProjectNotifier();
});

class ProjectNotifier extends Notifier<List<ProjectModel>> {
  @override
  List<ProjectModel> build() {
    return _initialProjects;
  }

  static final List<ProjectModel> _initialProjects = [
    ProjectModel(
      id: 'p1',
      title: 'AI Study Assistant',
      teamMembers: ['John Doe', 'Jane Cooper', 'Robert Fox'],
      progress: 0.75,
      deadline: DateTime.now().add(const Duration(days: 14)),
      description: 'Building a RAG-based AI assistant for student notes.',
      color: Colors.blue,
    ),
    ProjectModel(
      id: 'p2',
      title: 'Decentralized Voting',
      teamMembers: ['John Doe', 'Theresa Webb'],
      progress: 0.30,
      deadline: DateTime.now().add(const Duration(days: 30)),
      description: 'Blockchain-based voting system for university elections.',
      color: Colors.orange,
    ),
    ProjectModel(
      id: 'p3',
      title: 'Fitness Tracker App',
      teamMembers: ['John Doe', 'Albert Flores', 'Savannah Nguyen'],
      progress: 0.90,
      deadline: DateTime.now().add(const Duration(days: 5)),
      description: 'Cross-platform mobile app for tracking workouts and diet.',
      color: Colors.teal,
    ),
  ];
}

// chatProvider removed — real unread counts come from messagesNotifierProvider

// ── Dashboard Notes & Questions ───────────────────────────────────────────────

enum DashboardNoteType { note, question }

class DashboardNote {
  final String id;
  final String content;
  final DashboardNoteType type;
  final DateTime createdAt;
  final bool isResolved; // for questions: marks answered

  DashboardNote({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.isResolved = false,
  });

  DashboardNote copyWith({
    String? content,
    DashboardNoteType? type,
    bool? isResolved,
  }) =>
      DashboardNote(
        id: id,
        content: content ?? this.content,
        type: type ?? this.type,
        createdAt: createdAt,
        isResolved: isResolved ?? this.isResolved,
      );
}

final dashboardNotesProvider =
    NotifierProvider<DashboardNotesNotifier, List<DashboardNote>>(
        DashboardNotesNotifier.new);

class DashboardNotesNotifier extends Notifier<List<DashboardNote>> {
  @override
  List<DashboardNote> build() => [];

  void add(String content, DashboardNoteType type) {
    state = [
      ...state,
      DashboardNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        type: type,
        createdAt: DateTime.now(),
      ),
    ];
  }

  void toggleResolved(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isResolved: !n.isResolved) else n,
    ];
  }

  void remove(String id) => state = state.where((n) => n.id != id).toList();
}

