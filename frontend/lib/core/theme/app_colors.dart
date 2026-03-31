import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() => ThemeModeNotifier());
final notificationProvider = NotifierProvider<NotificationNotifier, List<AppNotification>>(() => NotificationNotifier());
final isNotificationsEnabledProvider = NotifierProvider<NotificationsEnabledNotifier, bool>(() => NotificationsEnabledNotifier());
final isEmailSummaryEnabledProvider = NotifierProvider<EmailSummaryEnabledNotifier, bool>(() => EmailSummaryEnabledNotifier());

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

class EmailSummaryEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;
  void toggle() => state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  void setTheme(ThemeMode mode) => state = mode;
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [
    AppNotification(
      id: '1',
      title: 'New Assignment',
      message: 'Mobile App Assignment 3 has been posted.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Project Deadline',
      message: 'AI Study Assistant milestone is due tomorrow.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: '3',
      title: 'New Message',
      message: 'Dr. Sarah Mitchell sent you a message.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  void add(AppNotification notification) => state = [notification, ...state];
  void remove(String id) => state = state.where((n) => n.id != id).toList();
  void clearAll() => state = [];
  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) AppNotification(id: n.id, title: n.title, message: n.message, timestamp: n.timestamp, isRead: true) else n
    ];
  }
}

class AppColors {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color cardBackground = Color(0xFF21262D);
  static const Color accent = Color(0xFF58A6FF);
  static const Color secondaryBackground = Color(0xFF010409);
  static const Color textBody = Color(0xFF8B949E);
  static const Color textHeading = Color(0xFFC9D1D9);
  
  static const Color priorityHigh = Color(0xFFFF4D4D);
  static const Color priorityMedium = Color(0xFFFFD93D);
  static const Color priorityLow = Color(0xFF4CAF50);
  
  static const Color todoColor = Color(0xFF7D8590);
  static const Color inProgressColor = Color(0xFFD29922);
  static const Color doneColor = Color(0xFF238636);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF58A6FF), Color(0xFF1F6FEB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCardBackground = Colors.white;
  static const Color lightTextBody = Color(0xFF57606A);
  static const Color lightTextHeading = Color(0xFF24292F);
  static const Color lightSecondaryBackground = Color(0xFFF3F4F6);

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? background : lightBackground;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? surface : lightSurface;
  }
  
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardBackground : lightCardBackground;
  }

  static Color getHeadingColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textHeading : lightTextHeading;
  }

  static Color getBodyColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textBody : lightTextBody;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
  }
}
