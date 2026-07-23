class Chat {
  final String id;
  final String type;
  final String name;
  final String description;
  final String avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChatMessage? lastMessage;
  final int unreadCount;

  const Chat({
    required this.id,
    required this.type,
    this.name = '',
    this.description = '',
    this.avatarUrl = '',
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] ?? '',
      type: json['type'] ?? 'personal',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String type;
  final String fileUrl;
  final String replyTo;
  final bool isPinned;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageSender? sender;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.content = '',
    this.type = 'text',
    this.fileUrl = '',
    this.replyTo = '',
    this.isPinned = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      fileUrl: json['file_url'] ?? '',
      replyTo: json['reply_to'] ?? '',
      isPinned: json['is_pinned'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      sender: json['sender'] != null ? MessageSender.fromJson(json['sender']) : null,
    );
  }
}

class MessageSender {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  const MessageSender({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
    );
  }
}
