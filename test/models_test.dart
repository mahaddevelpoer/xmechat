import 'package:flutter_test/flutter_test.dart';
import 'package:xmechat/models/models.dart';

void main() {
  test('MessageModel parses core database fields', () {
    final createdAt = DateTime.utc(2026, 5, 21, 10);
    final message = MessageModel.fromMap({
      'id': 'm1',
      'chat_id': 'c1',
      'sender_id': 'u1',
      'receiver_id': 'u2',
      'text': 'hello',
      'type': 'text',
      'status': 'read',
      'created_at': createdAt.toIso8601String(),
    });

    expect(message.id, 'm1');
    expect(message.chatId, 'c1');
    expect(message.text, 'hello');
    expect(message.type, MessageType.text);
    expect(message.status, MessageStatus.read);
  });
}
