import 'package:flutter/material.dart';

/// Assigns a consistent, vibrant color to any subject based on its name.
/// The same subject name will always get the same color across the entire app.
class SubjectColorManager {
  static const List<Color> _palette = [
    Color(0xFF58A6FF), // Blue
    Color(0xFF3FB950), // Green
    Color(0xFFF78166), // Coral
    Color(0xFFD2A8FF), // Purple
    Color(0xFFFFA657), // Orange
    Color(0xFF79C0FF), // Sky
    Color(0xFFFF7B72), // Red
    Color(0xFF56D364), // Mint
    Color(0xFFE3B341), // Gold
    Color(0xFF7EE787), // Light Green
  ];

  static Color forSubject(String subjectName) {
    final hash = subjectName.toLowerCase().codeUnits.fold(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  static Color forSubjectDark(String subjectName) {
    return forSubject(subjectName).withOpacity(0.85);
  }

  static LinearGradient gradientForSubject(String subjectName) {
    final base = forSubject(subjectName);
    return LinearGradient(
      colors: [base, base.withOpacity(0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
