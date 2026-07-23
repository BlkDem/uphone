import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  Future<List<Map<String, dynamic>>> getMembers(String chatId) async {
    final response = await _dio.get('/api/v1/chats/$chatId/members');
    final data = response.data as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<ChatMessage>> getMediaMessages(String chatId, {String? mediaType}) async {
    final params = <String, dynamic>{};
    if (mediaType != null) params['type'] = mediaType;
    final response = await _dio.get('/api/v1/chats/$chatId/media', queryParameters: params);
    final data = response.data as List;
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<ChatMessage> forwardMessage(String chatId, String msgId, String targetChatId) async {
    final response = await _dio.post(
      '/api/v1/chats/$chatId/messages/$msgId/forward',
      data: {'chat_id': targetChatId},
    );
    return ChatMessage.fromJson(response.data);
  }

  Future<void> markAsRead(String chatId, String messageId) async {
    await _dio.post('/api/v1/chats/$chatId/read', data: {
      'message_id': messageId,
    });
  }

  Future<Map<String, String>> uploadFile(String filename, String mimeType, Uint8List bytes) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post('/api/v1/upload', data: formData);
    final data = response.data;
    return {'url': data['url'] as String, 'filename': data['filename'] as String};
  }

  Future<ChatMessage> sendMessageWithFile(
    String chatId, {
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final uploadResult = await uploadFile(filename, mimeType, bytes);
    final type = mimeType.startsWith('image/')
        ? 'image'
        : mimeType.startsWith('video/')
            ? 'video'
            : mimeType.startsWith('audio/')
                ? 'voice'
                : 'file';
    final response = await _dio.post('/api/v1/chats/$chatId/messages', data: {
      'content': '',
      'type': type,
      'file_url': uploadResult['url'],
    });
    return ChatMessage.fromJson(response.data);
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
  final String currentUserId;

  ChatNotifier(this._repository, this._wsClient, this.currentUserId) : super(const ChatState()) {
    _wsClient.onMessage = _handleWsMessage;
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final payload = message['payload'];

    switch (type) {
      case 'message.new':
        if (payload is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(payload);
          final alreadyHas = state.messages.any((m) => m.id == msg.id);
          if (!alreadyHas) {
            _addMessage(msg);
          } else {
            _updateChatLastMessage(msg);
          }
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
      case 'message.read':
        if (payload is Map<String, dynamic>) {
          final chatId = payload['chatId'] as String?;
          if (chatId != null) {
            final updatedMessages = state.messages.map((m) {
              if (m.chatId == chatId &&
                  m.senderId == currentUserId &&
                  !m.isDeleted &&
                  m.status != 'read') {
                return ChatMessage(
                  id: m.id,
                  chatId: m.chatId,
                  senderId: m.senderId,
                  content: m.content,
                  type: m.type,
                  fileUrl: m.fileUrl,
                  replyTo: m.replyTo,
                  isPinned: m.isPinned,
                  isDeleted: m.isDeleted,
                  status: 'read',
                  createdAt: m.createdAt,
                  updatedAt: m.updatedAt,
                  sender: m.sender,
                );
              }
              return m;
            }).toList();
            state = state.copyWith(messages: updatedMessages);

            final updatedChats = state.chats.map((chat) {
              if (chat.id == chatId && chat.unreadCount > 0) {
                return Chat(
                  id: chat.id,
                  type: chat.type,
                  name: chat.name,
                  description: chat.description,
                  avatarUrl: chat.avatarUrl,
                  createdBy: chat.createdBy,
                  createdAt: chat.createdAt,
                  updatedAt: chat.updatedAt,
                  lastMessage: chat.lastMessage,
                  unreadCount: chat.unreadCount - 1,
                );
              }
              return chat;
            }).toList();
            state = state.copyWith(chats: updatedChats);
          }
        }
        break;
    }
  }

  void _addMessage(ChatMessage msg) {
    if (msg.chatId == state.activeChatId) {
      state = state.copyWith(messages: [...state.messages, msg]);
      if (msg.senderId != currentUserId) {
        markAsRead(msg.chatId);
      }
    } else if (msg.senderId != currentUserId) {
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
            updatedAt: chat.updatedAt,
            lastMessage: chat.lastMessage,
            unreadCount: chat.unreadCount + 1,
          );
        }
        return chat;
      }).toList();
      state = state.copyWith(chats: updatedChats);
    }
    _updateChatLastMessage(msg);
  }

  void _updateChatLastMessage(ChatMessage msg) {
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
          unreadCount: chat.unreadCount,
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
      // Mark chat as read
      await markAsRead(chatId);
    } catch (_) {
      state = state.copyWith(isLoadingMessages: false);
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      // Get the last message ID to mark as read
      final messages = await _repository.getMessages(chatId, limit: 1);
      if (messages.isNotEmpty) {
        final lastMsg = messages.first;
        await _repository.markAsRead(chatId, lastMsg.id);
        // Reset unread count locally
        final updatedChats = state.chats.map((chat) {
          if (chat.id == chatId) {
            return Chat(
              id: chat.id,
              type: chat.type,
              name: chat.name,
              description: chat.description,
              avatarUrl: chat.avatarUrl,
              createdBy: chat.createdBy,
              createdAt: chat.createdAt,
              updatedAt: chat.updatedAt,
              lastMessage: chat.lastMessage,
              unreadCount: 0,
            );
          }
          return chat;
        }).toList();
        state = state.copyWith(chats: updatedChats);
      }
    } catch (_) {}
  }

  Future<void> closeChat() async {
    final chatId = state.activeChatId;
    final msgs = state.messages;
    state = state.copyWith(activeChatId: null, messages: []);
    if (chatId != null && msgs.isNotEmpty) {
      final lastMsg = msgs.last;
      await markAsRead(chatId);
    }
  }

  Future<void> sendMessage(String chatId, String content) async {
    try {
      final msg = await _repository.sendMessage(chatId, content: content);
      _onMessageSent(chatId, msg);
    } catch (_) {}
  }

  Future<void> sendFile(String chatId, String filename, String mimeType, Uint8List bytes) async {
    try {
      final msg = await _repository.sendMessageWithFile(chatId, filename: filename, mimeType: mimeType, bytes: bytes);
      _onMessageSent(chatId, msg);
    } catch (e) {
      debugPrint('sendFile error: $e');
    }
  }

  void _onMessageSent(String chatId, ChatMessage msg) {
    final updatedChats = state.chats.map((chat) {
      if (chat.id == chatId) {
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
          unreadCount: 0,
        );
      }
      return chat;
    }).toList();
    updatedChats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(chats: updatedChats);
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

  Future<Chat?> createPersonalChat(String userEmail) async {
    try {
      final chat = await _repository.createChat(
        type: 'personal',
        members: [userEmail],
      );
      final alreadyExists = state.chats.any((c) => c.id == chat.id);
      if (!alreadyExists) {
        state = state.copyWith(chats: [chat, ...state.chats]);
      }
      return chat;
    } catch (_) {
      return null;
    }
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
    ref.read(authProvider).user?.id ?? '',
  );
});
