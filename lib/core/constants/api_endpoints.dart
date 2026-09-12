import 'dart:async';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiEndpoints {
  // Configured default host:
  // Production: https://appserver-production-0949.up.railway.app
  // Configurable via --dart-define=BACKEND_URL=...
  static const String _defaultHost = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://appserver-production-0949.up.railway.app',
  );

  static String _sanitize(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String activeHost = _sanitize(_defaultHost);

  static String get host => activeHost;
  static String get baseUrl => '${_sanitize(activeHost)}/api';
  static String get socketUrl => _sanitize(activeHost);

  /// Automatically tests candidate hosts if running locally in debug mode
  static Future<String> autoDetectWorkingHost() async {
    if (kIsWeb || kReleaseMode) {
      activeHost = _sanitize(_defaultHost);
      return activeHost;
    }

    // In debug mode, if explicit BACKEND_URL wasn't provided, check local fallbacks
    if (_defaultHost != 'https://appserver-production-0949.up.railway.app') {
      activeHost = _sanitize(_defaultHost);
      return activeHost;
    }
// https://appserver-production-0949.up.railway.app
    final candidates = [
      'http://10.0.2.2:5000',
      'http://127.0.0.1:5000',
      'https://appserver-production-0949.up.railway.app',
    ];

    for (final candidate in candidates) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 900);
        final uri = Uri.parse('$candidate/api/health');
        final req = await client.getUrl(uri);
        final resp = await req.close();
        if (resp.statusCode == 200) {
          activeHost = _sanitize(candidate);
          client.close();
          return activeHost;
        }
        client.close();
      } catch (_) {
        // Try next candidate
      }
    }

    activeHost = _sanitize(_defaultHost);
    return activeHost;
  }

  // Auth
  static const String register = '/auth/register';
  static const String startRegistration = '/auth/start-registration';
  static const String verifyRegistrationOtp = '/auth/verify-registration-otp';
  static const String resendRegistrationOtp = '/auth/resend-registration-otp';
  static const String login = '/auth/login';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyResetOtp = '/auth/verify-reset-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';
  static const String deleteAccount = '/auth/delete-account';
  static const String uploadAvatar = '/auth/upload-avatar';

  // In-App Update Check
  static const String appVersion = '/app/version';

  // Profile & User
  static const String me = '/users/me';
  static const String updatePrivacy = '/users/me/privacy';
  static const String uploadMedia = '/users/me/upload';
  static const String updateLocation = '/users/me/location';
  static String userProfile(String id) => '/users/$id';
  static String userDistance(String id) => '/users/$id/distance';

  // Discovery, Swiping & Likes
  static const String discoveryFeed = '/discovery/feed';
  static const String swipe = '/discovery/swipe';
  static const String likes = '/discovery/likes';
  static String removeLike(String targetUserId) =>
      '/discovery/likes/$targetUserId';
  static String relationshipFeed(String type) =>
      '/discovery/relationships/$type';
  static const String matches = '/discovery/matches';
  static String unmatch(String id) => '/discovery/matches/$id';

  // Daily Mood
  static const String mood = '/mood';
  static const String todayMood = '/mood/today';

  // Chats & Messaging
  static const String chats = '/chats';
  static String chatMessages(String conversationId) =>
      '/chats/$conversationId/messages';
  static const String sendMessage = '/chats/messages';
  static String messageReactions(String messageId) =>
      '/chats/messages/$messageId/reactions';
  static String messageForward(String messageId) =>
      '/chats/messages/$messageId/forward';
  static const String chatUpload = '/chats/upload';
  static const String globalChatMessages = '/global-chat/messages';
  static String globalChatMessage(String id) => '/global-chat/messages/$id';

  // Gifts & Rankings
  static const String gifts = '/gifts';
  static const String sendGift = '/gifts/send';
  static const String giftHistory = '/gifts/history';
  static const String ranking = '/ranking';

  // Confessions
  static const String confessions = '/confessions';
  static String confessionLike(String id) => '/confessions/$id/like';
  static String confessionComments(String id) => '/confessions/$id/comments';

  // Safety & Notifications
  static const String blockUser = '/safety/block';
  static const String report = '/safety/report';
  static const String notifications = '/notifications';
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';
  static const String notificationsReadAll = '/notifications/read-all';

  // FCM Device Token
  static const String updateFcmToken = '/fcm/token';
}
