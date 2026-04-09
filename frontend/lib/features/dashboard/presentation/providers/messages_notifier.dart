import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/api_message_model.dart';
import '../../../../core/services/api_service.dart';

class MessagesNotifier extends AutoDisposeFamilyAsyncNotifier<List<ApiMessageModel>, int> {
  bool _hasMore = true;
  bool _isFetchingMore = false;
  
  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  @override
  Future<List<ApiMessageModel>> build(int channelId) async {
    final prefs = await SharedPreferences.getInstance();
    List<ApiMessageModel> cachedMsgs = [];
    
    // 1. Load from offline cache first (fast path)
    final cachedStr = prefs.getString('chat_cache_$channelId');
    if (cachedStr != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedStr);
        cachedMsgs = jsonList.map((e) => ApiMessageModel.fromJson(e)).toList();
      } catch (_) {}
    }

    // Initialize state with cache immediately if available before fetching
    if (cachedMsgs.isNotEmpty) {
      state = AsyncValue.data(cachedMsgs);
    }

    // 2. Fetch fresh from network
    try {
      final response = await ApiService().getMessages(channelId, limit: 50);
      final data = response.data as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>? ?? [];
      final msgs = list.map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>)).toList();
      
      if (msgs.length < 50) _hasMore = false;
      
      // Update cache
      prefs.setString('chat_cache_$channelId', jsonEncode(list));
      
      return msgs;
    } catch (e) {
      if (cachedMsgs.isNotEmpty) return cachedMsgs;
      rethrow;
    }
  }

  void append(ApiMessageModel msg) {
    if (state.value != null) {
      state = AsyncValue.data([...state.value!, msg]);
      // Silently update cache
      SharedPreferences.getInstance().then((prefs) {
        // Just cache the last 50 to prevent bloat
        final subset = state.value!.length > 50 ? state.value!.sublist(state.value!.length - 50) : state.value!;
        // Note: we'd need a toJson on model. Since we don't have it, we skip caching live appends for now, 
        // they'll be cached next reload.
      });
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isFetchingMore) return;
    
    final currentMsgs = state.value;
    if (currentMsgs == null || currentMsgs.isEmpty) return;
    
    _isFetchingMore = true;
    final cursorId = currentMsgs.first.id;
    
    try {
      final response = await ApiService().getMessages(arg, cursor: cursorId, limit: 50);
      final data = response.data as Map<String, dynamic>;
      final list = data['messages'] as List<dynamic>? ?? [];
      final moreMsgs = list.map((e) => ApiMessageModel.fromJson(e as Map<String, dynamic>)).toList();
      
      if (moreMsgs.length < 50) _hasMore = false;
      
      state = AsyncValue.data([...moreMsgs, ...currentMsgs]);
    } catch (e) {
      // Ignore network errors on pagination
    } finally {
      _isFetchingMore = false;
    }
  }
}

final messagesNotifierProvider =
    AutoDisposeAsyncNotifierProviderFamily<MessagesNotifier, List<ApiMessageModel>, int>(
  MessagesNotifier.new,
);
