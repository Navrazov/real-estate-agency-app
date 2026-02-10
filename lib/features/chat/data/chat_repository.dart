import '../../../core/api/api_client.dart';
import '../domain/message.dart';

class ChatRepository {
  final ApiClient _api = ApiClient();

  Future<List<Conversation>> getConversations() async {
    return _api.get<List<Conversation>>(
      '/chat/conversations',
      (data) => (data as List<dynamic>)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Conversation> createConversation(String participantId, {String? listingId}) async {
    final body = <String, dynamic>{'participantId': participantId};
    if (listingId != null) body['listingId'] = listingId;
    return _api.post<Conversation>(
      '/chat/conversations',
      body,
      (data) => Conversation.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<Message>> getMessages(String conversationId, {int page = 1}) async {
    return _api.get<List<Message>>(
      '/chat/conversations/$conversationId/messages?page=$page',
      (data) => (data as List<dynamic>)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Message> sendMessage(String conversationId, String text) async {
    return _api.post<Message>(
      '/chat/conversations/$conversationId/messages',
      {'text': text},
      (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> markRead(String conversationId) async {
    await _api.patch<Map<String, dynamic>>(
      '/chat/conversations/$conversationId/read',
      {},
      (data) => data as Map<String, dynamic>,
    );
  }

  Future<int> getUnreadCount() async {
    final result = await _api.get<Map<String, dynamic>>(
      '/chat/unread',
      (data) => data as Map<String, dynamic>,
    );
    return result['count'] as int? ?? 0;
  }
}
