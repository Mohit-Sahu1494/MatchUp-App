import 'package:flutter/material.dart';
import '../features/home/presentation/home_discovery_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/matching/presentation/likes_screen.dart';
import '../features/global_chat/presentation/global_chat_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/calling/services/webrtc_service.dart';
import '../features/calling/presentation/call_screen.dart';
import '../core/network/socket_service.dart';
import '../core/theme/app_colors.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({super.key});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  int _currentIndex = 0;
  final WebRTCService _webrtc = WebRTCService();
  final SocketService _socket = SocketService();

  final List<Widget> _screens = const [
    HomeDiscoveryScreen(),
    ExploreScreen(),
    LikesScreen(),
    GlobalChatScreen(),
    ProfileScreen(),
  ];

  bool _isCallScreenActive = false;

  @override
  void initState() {
    super.initState();
    _setupIncomingCallListener();
    _setupGlobalSocketListeners();
  }

  void _setupGlobalSocketListeners() {
    _socket.connect().then((_) {
      _socket.on('new_notification', _handleGlobalNotification);
      _socket.on('gift_received', _handleGlobalGift);
    }).catchError((_) {});
  }

  void _handleGlobalNotification(dynamic data) {
    if (!mounted) return;
    try {
      final notif = data is Map ? data : {};
      final title = notif['title'] as String? ?? 'New Notification';
      final body = notif['body'] as String? ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primary,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              if (body.isNotEmpty)
                Text(body,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  void _handleGlobalGift(dynamic data) {
    if (!mounted) return;
    try {
      final gift = data is Map ? data['gift'] ?? data : {};
      final giftName = gift['giftName'] ?? gift['name'] ?? 'a campus gift';
      final icon = gift['giftIcon'] ?? gift['icon'] ?? '🎁';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.accent,
          content: Text('$icon You received $giftName!',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    } catch (_) {}
  }

  /// Global incoming call listener — works from any screen
  void _setupIncomingCallListener() {
    // Init renderers silently so they're ready
    _webrtc.initRenderers().catchError((_) {});
    _webrtc.onIncomingCall = (callData) {
      if (!mounted) return;
      _showIncomingCallScreen(callData);
    };
  }

  void _showIncomingCallScreen(Map<String, dynamic> callData) {
    if (_isCallScreenActive) return;
    _isCallScreenActive = true;

    final callerName = callData['callerName'] as String? ?? 'Unknown';
    final callerPhoto = callData['callerPhoto'] as String? ?? '';
    final callType = callData['callType'] as String? ?? 'video';
    final isVideo = callType == 'video';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          webrtcService: _webrtc,
          peerName: callerName,
          peerPhoto: callerPhoto,
          isVideo: isVideo,
          incomingCallData: callData,
        ),
      ),
    ).then((_) {
      _isCallScreenActive = false;
    });
  }

  @override
  void dispose() {
    _socket.off('new_notification', _handleGlobalNotification);
    _socket.off('gift_received', _handleGlobalGift);
    _webrtc.onIncomingCall = null;
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        indicatorColor: AppColors.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon:
                Icon(Icons.local_fire_department, color: AppColors.primary),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppColors.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum, color: AppColors.primary),
            label: 'Global Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
