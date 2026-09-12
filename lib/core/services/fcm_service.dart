import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/matching/presentation/likes_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/calling/presentation/call_screen.dart';
import '../../features/calling/services/webrtc_service.dart';

/// Top-level background message handler invoked when the app is backgrounded or terminated.
/// Must be annotated with `@pragma('vm:entry-point')` for AOT/background isolation.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[FCM Background] Firebase initialize error: $e');
  }
  debugPrint('[FCM Background] Message received: ${message.messageId}, data: ${message.data}');
}

class FcmService {
  static GlobalKey<NavigatorState>? navigatorKey;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'matchup_notifications',
    'MatchUp Notifications',
    description: 'Alerts for private messages, matches, incoming calls, and gifts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static bool _isInitialized = false;

  /// Initializes Firebase and FCM notification listeners.
  /// Safely handles cases where Firebase credentials (google-services.json) are not yet supplied.
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    if (navKey != null) navigatorKey = navKey;

    try {
      await Firebase.initializeApp();
      debugPrint('[FCM] Firebase initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Firebase initialization skipped or failed: $e');
      // If Firebase fails to initialize (e.g. google-services.json not configured yet), exit gracefully
      return;
    }

    // Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request user permissions (crucial for Android 13+ and iOS)
    await _requestPermissions();

    // Initialize local notifications for heads-up alerts when foregrounded
    await _initializeLocalNotifications();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] onMessageOpenedApp: ${message.data}');
      handleNotificationNavigation(message.data);
    });

    // Check if app was opened directly from a terminated state via a notification click
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM] getInitialMessage: ${message.data}');
        // Allow widget tree to settle before navigating
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(message.data);
        });
      }
    });

    // Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      registerDeviceToken(fcmToken: newToken);
    });

    _isInitialized = true;
  }

  /// Request notification permissions (POST_NOTIFICATIONS on Android 13+)
  static Future<void> _requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (Platform.isAndroid) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[FCM] Error requesting permissions: $e');
    }
  }

  /// Sets up flutter_local_notifications plugin and creates notification channels
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            handleNotificationNavigation(data);
          } catch (e) {
            debugPrint('[FCM] Failed to parse local notification payload: $e');
          }
        }
      },
    );

    // Create high-importance Android notification channel
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_defaultChannel);
  }

  /// Display heads-up banner via flutter_local_notifications when app is in the foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received: ${message.notification?.title}, data: ${message.data}');

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'MatchUp';
    final body = notification?.body ?? message.data['body'] ?? '';

    // Show system notification banner
    final androidDetails = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Retrieve the current FCM token from Firebase and sync it to the backend User model
  static Future<void> registerDeviceToken({String? fcmToken}) async {
    try {
      final jwtToken = await TokenStorage.getToken();
      if (jwtToken == null || jwtToken.isEmpty) {
        debugPrint('[FCM] User not authenticated, skipping token registration');
        return;
      }

      final token = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Unable to retrieve device FCM token');
        return;
      }

      debugPrint('[FCM] Registering FCM token with backend...');
      final response = await ApiClient().post(
        ApiEndpoints.updateFcmToken,
        data: {'token': token},
      );

      if (response.data is Map && response.data['success'] == true) {
        debugPrint('[FCM] Token registered successfully on backend');
      } else {
        debugPrint('[FCM] Failed to register token: ${response.data}');
      }
    } catch (e) {
      debugPrint('[FCM] Error registering FCM token: $e');
    }
  }

  /// Unregister device token from backend upon user logout
  static Future<void> unregisterDeviceToken() async {
    try {
      debugPrint('[FCM] Clearing FCM token on backend...');
      await ApiClient().delete(ApiEndpoints.updateFcmToken);
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FCM] FCM token cleared successfully');
    } catch (e) {
      debugPrint('[FCM] Error clearing FCM token: $e');
    }
  }

  /// Navigates to appropriate screen depending on notification data payload
  static void handleNotificationNavigation(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('[FCM] NavigatorState not ready for navigation');
      return;
    }

    final type = (data['type'] ?? data['action'] ?? '').toString().toLowerCase();
    debugPrint('[FCM] Routing for notification type: "$type" with data: $data');

    switch (type) {
      case 'chat':
      case 'message':
        final conversationId = data['conversationId']?.toString();
        final senderId = data['senderId']?.toString() ?? '';
        final senderName = data['senderName']?.toString() ?? 'MatchUp Student';
        final senderPhoto = data['senderPhoto']?.toString() ?? '';

        if (conversationId != null && conversationId.isNotEmpty) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                conversationId: conversationId,
                recipientId: senderId,
                recipientName: senderName,
                recipientPhoto: senderPhoto,
              ),
            ),
          );
        } else {
          nav.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
        break;

      case 'match':
        final conversationId = data['conversationId']?.toString();
        final partnerName = data['partnerName']?.toString() ?? 'Your Match';
        final partnerPhoto = data['partnerPhoto']?.toString() ?? '';
        final senderId = data['senderId']?.toString() ?? '';

        if (conversationId != null && conversationId.isNotEmpty) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                conversationId: conversationId,
                recipientId: senderId,
                recipientName: partnerName,
                recipientPhoto: partnerPhoto,
              ),
            ),
          );
        } else {
          nav.push(
            MaterialPageRoute(builder: (_) => const LikesScreen()),
          );
        }
        break;

      case 'call':
        final action = data['action']?.toString();
        if (action == 'incoming_call') {
          final callerName = data['callerName']?.toString() ?? 'Student';
          final callerPhoto = data['callerPhoto']?.toString() ?? '';
          final callType = data['callType']?.toString() ?? 'video';
          final isVideo = callType == 'video';

          final webrtc = WebRTCService();
          webrtc.initRenderers().catchError((_) {});

          nav.push(
            MaterialPageRoute(
              builder: (_) => CallScreen(
                webrtcService: webrtc,
                peerName: callerName,
                peerPhoto: callerPhoto,
                isVideo: isVideo,
                incomingCallData: data,
              ),
            ),
          );
        } else {
          // Missed call or call alert -> go to notifications
          nav.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
        break;

      case 'like':
        nav.push(
          MaterialPageRoute(builder: (_) => const LikesScreen()),
        );
        break;

      case 'gift':
      case 'confession':
      case 'confession_like':
      case 'confession_comment':
      default:
        nav.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
    }
  }
}
