import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import 'storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = StorageService();

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected) return;
    final token = await _storage.read('adtu_token');

    _socket = io.io(
      AppConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ Socket disconnected');
    });

    _socket!.onConnectError((data) {
      debugPrint('⚠️ Socket connect error: $data');
    });
  }

  void joinChannel(int channelId) {
    _socket?.emit('channel:join', channelId);
  }

  void leaveChannel(int channelId) {
    _socket?.emit('channel:leave', channelId);
  }

  void sendMessage({
    required int channelId,
    required String content,
    int? parentId,
  }) {
    _socket?.emit('message:send', {
      'channelId': channelId,
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  void emitTypingStart(int channelId, String userName) {
    _socket
        ?.emit('typing:start', {'channelId': channelId, 'userName': userName});
  }

  void emitTypingStop(int channelId) {
    _socket?.emit('typing:stop', {'channelId': channelId});
  }

  /// Listen for new incoming messages in a channel.
  /// Clears any prior listener first to prevent stacking duplicates on widget rebuild.
  void onNewMessage(void Function(Map<String, dynamic>) callback) {
    _socket?.off('message:new');
    _socket?.on(
        'message:new', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onTypingStart(void Function(String userName) callback) {
    _socket?.off('typing:start');
    _socket?.on('typing:start', (data) => callback(data['userName'] ?? ''));
  }

  void onTypingStop(void Function() callback) {
    _socket?.off('typing:stop');
    _socket?.on('typing:stop', (_) => callback());
  }

  void onNewNotification(void Function(Map<String, dynamic>) callback) {
    _socket?.off('notification:new');
    _socket?.on('notification:new',
        (data) => callback(Map<String, dynamic>.from(data)));
  }

  void off(String event) => _socket?.off(event);

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
