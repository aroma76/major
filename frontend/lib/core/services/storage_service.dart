import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-platform token storage.
/// Web        → SharedPreferences (localStorage)
/// Android/iOS → FlutterSecureStorage (Keystore/Keychain)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _secure = const FlutterSecureStorage();

  // Cached prefs instance — avoids repeated async getInstance() on every request
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } else {
      return _secure.read(key: key);
    }
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    } else {
      await _secure.delete(key: key);
    }
  }
}
