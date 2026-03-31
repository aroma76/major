import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/chat_model.dart';

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

  static final List<TaskModel> _initialTasks = [
    TaskModel(
      id: '1',
      title: 'Mobile App Assignment 3',
      description: 'Implement a Flutter login screen with Riverpod and animations.',
      subject: 'Mobile Development',
      status: TaskStatus.todo,
      priority: TaskPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 3)),
    ),
    TaskModel(
      id: '2',
      title: 'Database Schema Design',
      description: 'Create a normalization diagram for the student portal.',
      subject: 'Database Management',
      status: TaskStatus.inProgress,
      priority: TaskPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 5)),
    ),
    TaskModel(
      id: '3',
      title: 'Operating System Midterm Prep',
      description: 'Review memory management and process scheduling.',
      subject: 'Operating Systems',
      status: TaskStatus.todo,
      priority: TaskPriority.low,
      dueDate: DateTime.now().add(const Duration(days: 1)),
    ),
    TaskModel(
      id: '4',
      title: 'Algorithm Analysis Report',
      description: 'Summarize the Big O complexity of common sorting algorithms.',
      subject: 'Design & Analysis of Algorithms',
      status: TaskStatus.done,
      priority: TaskPriority.medium,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TaskModel(
      id: '5',
      title: 'Cybersecurity Lab 4',
      description: 'Practice SQL injection and buffer overflow exploits.',
      subject: 'Network Security',
      status: TaskStatus.inProgress,
      priority: TaskPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 7)),
    ),
  ];

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

final chatProvider = NotifierProvider<ChatNotifier, List<ChatModel>>(() {
  return ChatNotifier();
});

class ChatNotifier extends Notifier<List<ChatModel>> {
  @override
  List<ChatModel> build() {
    return _initialChats;
  }

  static final List<ChatModel> _initialChats = [
    ChatModel(
      id: 'c1',
      name: 'Class Group Chat',
      lastMessage: 'Hey, has anyone finished Lab 4?',
      lastMessageTime: '12:45 PM',
      imageUrl: 'https://i.pravatar.cc/150?img=5',
      unreadCount: 4,
    ),
    ChatModel(
      id: 'c2',
      name: 'Dr. Sarah Mitchell',
      lastMessage: 'Can you share the notes for...',
      lastMessageTime: '10:30 AM',
      imageUrl: 'https://i.pravatar.cc/150?img=1',
      unreadCount: 0,
      isOnline: true,
    ),
    ChatModel(
      id: 'c3',
      name: 'Project Team Alpha',
      lastMessage: 'Let\'s meet at 5:00 PM.',
      lastMessageTime: 'Yesterday',
      imageUrl: 'https://i.pravatar.cc/150?img=8',
      unreadCount: 1,
    ),
  ];
}
