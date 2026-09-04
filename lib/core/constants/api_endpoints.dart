import 'dart:async';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  // Configured default host:
  // 127.0.0.1 (Phone over USB via adb reverse & Windows/Desktop)
  // 10.93.161.60 (Phone over Wi-Fi LAN)
  // 10.0.2.2 (Android QEMU emulator)
  // localhost (Web & iOS Simulator)
  // https://app-production-86ea.up.railway.app
  static String activeHost = 'https://appserver-production-0949.up.railway.app/';

  static String get host => activeHost;
  static String get baseUrl => '$activeHost/api';
  static String get socketUrl => activeHost;

  /// Automatically tests candidate hosts in parallel and selects the fastest responding one
  static Future<String> autoDetectWorkingHost() async {
    if (kIsWeb) {
      activeHost = 'https://appserver-production-0949.up.railway.app/';
      return activeHost;
    }

    final candidates = [
      'http://127.0.0.1:5000',
      'http://10.93.161.60:5000',
      'http://10.0.2.2:5000',
      'http://localhost:5000',
      'https://appserver-production-0949.up.railway.app/'
    ];

    for (final candidate in candidates) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 1200);
        final uri = Uri.parse('$candidate/api/health');
        final req = await client.getUrl(uri);
        final resp = await req.close();
        if (resp.statusCode == 200) {
          activeHost = candidate;
          client.close();
          return activeHost;
        }
        client.close();
      } catch (_) {
        // Try next candidate
      }
    }

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
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';
  static const String deleteAccount = '/auth/delete-account';

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

  // Safety
  static const String blockUser = '/safety/block';
  static const String report = '/safety/report';
  static const String notifications = '/notifications';
}
