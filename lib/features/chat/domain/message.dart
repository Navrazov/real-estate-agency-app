class Conversation {
  final String id;
  final List<String> participants;
  final String? listingId;
  final String? listingTitle;
  final String? lastMessage;
  final String? lastMessageAt;
  final OtherUser? otherUser;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.participants,
    this.listingId,
    this.listingTitle,
    this.lastMessage,
    this.lastMessageAt,
    this.otherUser,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participants: (json['participants'] as List<dynamic>).cast<String>(),
      listingId: json['listingId'] as String?,
      listingTitle: json['listingTitle'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] as String?,
      otherUser: json['otherUser'] != null
          ? OtherUser.fromJson(json['otherUser'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class OtherUser {
  final String id;
  final String? name;
  final String? phone;
  final String? avatar;
  final String? lastSeen;
  final bool online;

  OtherUser({required this.id, this.name, this.phone, this.avatar, this.lastSeen, this.online = false});

  factory OtherUser.fromJson(Map<String, dynamic> json) {
    return OtherUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      lastSeen: json['lastSeen'] as String?,
      online: json['online'] as bool? ?? false,
    );
  }

  String get displayName => name ?? phone ?? 'Пользователь';
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final bool read;
  final String createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.read = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['_id']) as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
    );
  }

  Message copyWith({bool? read}) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
