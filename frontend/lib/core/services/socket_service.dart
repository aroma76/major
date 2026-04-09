import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import 'storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final _storage = StorageService();

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected) return;
    final token = await _storage.read('adtu_token');

    _socket = IO.io(
      AppConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
    });

    _socket!.onConnectError((data) {
      print('⚠️ Socket connect error: $data');
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
    _socket?.emit('typing:start', {'channelId': channelId, 'userName': userName});
  }

  void emitTypingStop(int channelId) {
    _socket?.emit('typing:stop', {'channelId': channelId});
  }

  /// Listen for new incoming messages in a channel
  void onNewMessage(void Function(Map<String, dynamic>) callback) {
    _socket?.on('message:new', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void onTypingStart(void Function(String userName) callback) {
    _socket?.on('typing:start', (data) => callback(data['userName'] ?? ''));
  }

  void onTypingStop(void Function() callback) {
    _socket?.on('typing:stop', (_) => callback());
  }

  void onNewNotification(void Function(Map<String, dynamic>) callback) {
    _socket?.on('notification:new', (data) => callback(Map<String, dynamic>.from(data)));
  }

  void off(String event) => _socket?.off(event);

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
