import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/api_message_model.dart';
import '../../../../core/services/api_service.dart';

class MessagesState {
  final List<ApiMessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final bool isFetchingMore;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.isFetchingMore = false,
    this.error,
  });

  MessagesState copyWith({
    List<ApiMessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    bool? isFetchingMore,
    String? error,
  }) =>
      MessagesState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        isFetchingMore: isFetchingMore ?? this.isFetchingMore,
        error: error,
      );
}

/// Riverpod v3 family: argument is injected via constructor and stored as a
/// final field. The [Notifier.state] getter/setter is provided by the base class.
class MessagesNotifier extends Notifier<MessagesState> {
  MessagesNotifier(this.channelId);

  final int channelId;

  @override
  MessagesState build() {
    Future.microtask(_init);
    return const MessagesState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    List<ApiMessageModel> cachedMsgs = [];

    final cachedStr = prefs.getString('chat_cache_$channelId');
    if (cachedStr != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedStr);
        cachedMsgs = jsonList.map((e) => ApiMessageModel.fromJson(e)).toList();
        state = state.copyWith(messages: cachedMsgs, isLoading: true);
      } catch (_) {}
    }

    try {
      final response = await ApiService().getMessages(channelId, limit: 50);
      final data = response.data as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>? ?? [];
      final msgs = list
          .map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      prefs.setString('chat_cache_$channelId', jsonEncode(list));
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        hasMore: msgs.length >= 50,
        error: null,
      );
    } catch (e) {
      if (cachedMsgs.isNotEmpty) {
        state = state.copyWith(messages: cachedMsgs, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void append(ApiMessageModel msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isFetchingMore || state.messages.isEmpty) return;
    state = state.copyWith(isFetchingMore: true);
    final cursorId = state.messages.first.id;
    try {
      final response = await ApiService()
          .getMessages(channelId, cursor: cursorId, limit: 50);
      final data = response.data as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>? ?? [];
      final moreMsgs = list
          .map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        messages: [...moreMsgs, ...state.messages],
        hasMore: moreMsgs.length >= 50,
        isFetchingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isFetchingMore: false);
    }
  }
}

final messagesNotifierProvider = NotifierProvider.autoDispose
    .family<MessagesNotifier, MessagesState, int>(
  MessagesNotifier.new,
);
