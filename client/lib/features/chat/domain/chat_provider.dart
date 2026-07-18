import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/network/ws_client.dart';
import 'package:uphone_client/shared/models/chat.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';

class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  Future<List<Chat>> getChats() async {
    final response = await _dio.get('/api/v1/chats');
    final data = response.data as List;
    return data.map((json) => Chat.fromJson(json)).toList();
  }

  Future<Chat> createChat({
    required String type,
    required List<String> members,
    String name = '',
  }) async {
    final response = await _dio.post('/api/v1/chats', data: {
      'type': type,
      'members': members,
      'name': name,
    });
    return Chat.fromJson(response.data);
  }

  Future<List<ChatMessage>> getMessages(String chatId, {int limit = 50, int offset = 0}) async {
    final response = await _dio.get('/api/v1/chats/$chatId/messages',
        queryParameters: {'limit': limit, 'offset': offset});
    final data = response.data as List;
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<ChatMessage> sendMessage(String chatId, {required String content, String replyTo = ''}) async {
    final response = await _dio.post('/api/v1/chats/$chatId/messages', data: {
      'content': content,
      'reply_to': replyTo,
    });
    return ChatMessage.fromJson(response.data);
  }

  Future<void> editMessage(String chatId, String msgId, String content) async {
    await _dio.put('/api/v1/chats/$chatId/messages/$msgId', data: {
      'content': content,
    });
  }

  Future<void> deleteMessage(String chatId, String msgId) async {
    await _dio.delete('/api/v1/chats/$chatId/messages/$msgId');
  }

  Future<void> addReaction(String chatId, String msgId, String emoji) async {
    await _dio.post('/api/v1/chats/$chatId/messages/$msgId/react', data: {
      'emoji': emoji,
    });
  }
}

class ChatState {
  final List<Chat> chats;
  final String? activeChatId;
  final List<ChatMessage> messages;
  final bool isLoadingChats;
  final bool isLoadingMessages;
  final Map<String, bool> typingUsers;

  const ChatState({
    this.chats = const [],
    this.activeChatId,
    this.messages = const [],
    this.isLoadingChats = false,
    this.isLoadingMessages = false,
    this.typingUsers = const {},
  });

  ChatState copyWith({
    List<Chat>? chats,
    String? activeChatId,
    List<ChatMessage>? messages,
    bool? isLoadingChats,
    bool? isLoadingMessages,
    Map<String, bool>? typingUsers,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      activeChatId: activeChatId ?? this.activeChatId,
      messages: messages ?? this.messages,
      isLoadingChats: isLoadingChats ?? this.isLoadingChats,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final WsClient _wsClient;

  ChatNotifier(this._repository, this._wsClient) : super(const ChatState()) {
    _wsClient.connect(
      '',
      onMessage: _handleWsMessage,
    );
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final payload = message['payload'];

    switch (type) {
      case 'message.new':
        if (payload is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(payload);
          _addMessage(msg);
        }
        break;
      case 'typing.start':
        if (payload is Map<String, dynamic>) {
          final userId = payload['userId'] as String?;
          final chatId = payload['chatId'] as String?;
          if (userId != null && chatId != null) {
            state = state.copyWith(
              typingUsers: {...state.typingUsers, '${chatId}_$userId': true},
            );
          }
        }
        break;
      case 'typing.stop':
        if (payload is Map<String, dynamic>) {
          final userId = payload['userId'] as String?;
          final chatId = payload['chatId'] as String?;
          if (userId != null && chatId != null) {
            final newMap = Map<String, bool>.from(state.typingUsers);
            newMap.remove('${chatId}_$userId');
            state = state.copyWith(typingUsers: newMap);
          }
        }
        break;
    }
  }

  void _addMessage(ChatMessage msg) {
    if (msg.chatId == state.activeChatId) {
      state = state.copyWith(messages: [...state.messages, msg]);
    }

    final updatedChats = state.chats.map((chat) {
      if (chat.id == msg.chatId) {
        return Chat(
          id: chat.id,
          type: chat.type,
          name: chat.name,
          description: chat.description,
          avatarUrl: chat.avatarUrl,
          createdBy: chat.createdBy,
          createdAt: chat.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: msg,
        );
      }
      return chat;
    }).toList();

    updatedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(chats: updatedChats);
  }

  Future<void> loadChats() async {
    state = state.copyWith(isLoadingChats: true);
    try {
      final chats = await _repository.getChats();
      state = state.copyWith(chats: chats, isLoadingChats: false);
    } catch (_) {
      state = state.copyWith(isLoadingChats: false);
    }
  }

  Future<void> openChat(String chatId) async {
    state = state.copyWith(
      activeChatId: chatId,
      isLoadingMessages: true,
      messages: [],
    );
    try {
      final messages = await _repository.getMessages(chatId);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: messages, isLoadingMessages: false);
    } catch (_) {
      state = state.copyWith(isLoadingMessages: false);
    }
  }

  Future<void> closeChat() async {
    state = state.copyWith(activeChatId: null, messages: []);
  }

  Future<void> sendMessage(String chatId, String content) async {
    try {
      _wsClient.send({
        'type': 'message.send',
        'chatId': chatId,
        'content': content,
      });
    } catch (_) {}
  }

  void sendTypingStart(String chatId) {
    _wsClient.send({'type': 'typing.start', 'chatId': chatId});
  }

  void sendTypingStop(String chatId) {
    _wsClient.send({'type': 'typing.stop', 'chatId': chatId});
  }

  Future<void> editMessage(String chatId, String msgId, String content) async {
    try {
      await _repository.editMessage(chatId, msgId, content);
    } catch (_) {}
  }

  Future<void> deleteMessage(String chatId, String msgId) async {
    try {
      await _repository.deleteMessage(chatId, msgId);
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != msgId).toList(),
      );
    } catch (_) {}
  }

  Future<void> addReaction(String chatId, String msgId, String emoji) async {
    try {
      await _repository.addReaction(chatId, msgId, emoji);
    } catch (_) {}
  }

  Future<void> createPersonalChat(String userEmail) async {
    try {
      final chat = await _repository.createChat(
        type: 'personal',
        members: [userEmail],
      );
      state = state.copyWith(chats: [chat, ...state.chats]);
    } catch (_) {}
  }

  Future<void> createGroupChat({
    required String name,
    required String type,
    required List<String> members,
  }) async {
    try {
      final chat = await _repository.createChat(
        type: type,
        members: members,
        name: name,
      );
      state = state.copyWith(chats: [chat, ...state.chats]);
    } catch (_) {}
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider).dio);
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    ref.read(chatRepositoryProvider),
    ref.read(wsClientProvider),
  );
});
