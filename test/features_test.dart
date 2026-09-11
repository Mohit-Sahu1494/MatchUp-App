import 'package:flutter_test/flutter_test.dart';
import 'package:unimatch_app/core/services/update_service.dart';
import 'package:unimatch_app/features/chat/models/message_model.dart';

void main() {
  group('1. Semantic Version Comparison', () {
    test('1.10.0 is recognized as newer than 1.9.0', () {
      expect(UpdateService.compareSemVer('1.10.0', '1.9.0'), greaterThan(0));
      expect(UpdateService.compareSemVer('1.9.0', '1.10.0'), lessThan(0));
    });

    test('Major and minor versions compare accurately', () {
      expect(UpdateService.compareSemVer('2.0.0', '1.99.99'), greaterThan(0));
      expect(UpdateService.compareSemVer('1.0.1', '1.0.0'), greaterThan(0));
      expect(UpdateService.compareSemVer('1.0.0', '1.0.0'), equals(0));
    });

    test('Handles v prefix and build number suffix', () {
      expect(UpdateService.compareSemVer('v1.2.3+5', '1.2.3'), equals(0));
      expect(UpdateService.compareSemVer('v1.3.0', '1.2.9+99'), greaterThan(0));
    });
  });

  group('2. Message Timestamp Parsing', () {
    test('UTC ISO 8601 string is converted to local timezone', () {
      const utcString = '2026-09-11T08:00:00.000Z';
      final parsed = parseDateTime(utcString);
      expect(parsed.isUtc, false); // must be local
      // Verify local time conversion matches system local offset
      final expectedHour = DateTime.parse(utcString).toLocal().hour;
      expect(parsed.hour, equals(expectedHour));
    });

    test('Handles integer epoch milliseconds and seconds', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final parsedFromMs = parseDateTime(nowMs);
      expect(parsedFromMs.isUtc, false);
      expect((parsedFromMs.millisecondsSinceEpoch - nowMs).abs(), lessThan(1000));

      final nowSeconds = nowMs ~/ 1000;
      final parsedFromSec = parseDateTime(nowSeconds);
      expect(parsedFromSec.isUtc, false);
    });
  });

  group('3. Message Model Actions Serialization', () {
    test('Parses reactions and reactions summary accurately', () {
      final json = {
        'id': 'msg_123',
        'conversationId': 'conv_123',
        'senderId': 'user_1',
        'text': 'Hello world',
        'reactions': [
          {'userId': 'user_2', 'emoji': '❤️'},
          {'userId': 'user_3', 'emoji': '❤️'},
          {'userId': 'user_4', 'emoji': '👍'},
        ],
        'reactionsSummary': {'❤️': 2, '👍': 1},
        'myReaction': '❤️',
        'createdAt': '2026-09-11T12:00:00.000Z'
      };

      final msg = MessageModel.fromJson(json, currentUserId: 'user_2');
      expect(msg.id, 'msg_123');
      expect(msg.reactions.length, 3);
      expect(msg.reactionsSummary['❤️'], 2);
      expect(msg.reactionsSummary['👍'], 1);
      expect(msg.myReaction, '❤️');
      expect(msg.isMine, false);
    });

    test('Parses forwarded metadata accurately', () {
      final json = {
        'id': 'msg_456',
        'conversationId': 'conv_456',
        'senderId': 'user_1',
        'text': 'Forwarded text',
        'isForwarded': true,
        'forwardedFrom': {
          'messageId': 'orig_msg_1',
          'originalSenderId': 'orig_user_9',
          'originalSenderName': 'Sarah Connor'
        },
        'createdAt': '2026-09-11T12:00:00.000Z'
      };

      final msg = MessageModel.fromJson(json);
      expect(msg.isForwarded, true);
      expect(msg.forwardedFrom?.originalSenderName, 'Sarah Connor');
      expect(msg.forwardedFrom?.originalSenderId, 'orig_user_9');
    });

    test('Parses replyTo with deleted state gracefully', () {
      final json = {
        'id': 'msg_789',
        'conversationId': 'conv_456',
        'senderId': 'user_1',
        'text': 'Reply text',
        'replyTo': {
          'id': 'deleted_msg',
          'senderId': 'user_2',
          'isDeletedForEveryone': true,
          'text': 'This message was deleted'
        },
        'createdAt': '2026-09-11T12:00:00.000Z'
      };

      final msg = MessageModel.fromJson(json);
      expect(msg.replyTo, isNotNull);
      expect(msg.replyTo?.isDeletedForEveryone, true);
      expect(msg.replyTo?.text, 'This message was deleted');
    });
  });
}
