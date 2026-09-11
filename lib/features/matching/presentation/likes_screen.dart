import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/like_model.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../calling/services/webrtc_service.dart';
import '../../calling/presentation/call_screen.dart';

class ConversationModel {
  final String id;
  final String recipientId;
  final String name;
  final String username;
  final String profilePhoto;
  final String college;
  final String course;
  final int year;
  bool isOnline;
  String lastMessageText;
  DateTime lastMessageAt;
  int unreadCount;
  bool isTyping;

  ConversationModel({
    required this.id,
    required this.recipientId,
    required this.name,
    required this.username,
    required this.profilePhoto,
    required this.college,
    required this.course,
    required this.year,
    this.isOnline = false,
    required this.lastMessageText,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isTyping = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rec = json['recipient'] is Map
        ? json['recipient'] as Map<String, dynamic>
        : <String, dynamic>{};
    return ConversationModel(
      id: json['id'] ?? json['_id'] ?? '',
      recipientId: rec['id'] ?? rec['_id'] ?? '',
      name: rec['name'] ?? 'Student',
      username: rec['username'] ?? '',
      profilePhoto: rec['profilePhoto'] ?? '',
      college: rec['college'] ?? 'University',
      course: rec['course'] ?? '',
      year: rec['year'] is int
          ? rec['year']
          : int.tryParse(rec['year']?.toString() ?? '1') ?? 1,
      isOnline: rec['isOnline'] == true,
      lastMessageText: json['lastMessageText'] ?? '',
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
              DateTime.now(),
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount']
          : int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
      isTyping: false,
    );
  }
}

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  List<ConversationModel> _conversations = [];
  List<LikeModel> _matches = [];
  bool _isLoading = true;
  String? _errorMessage;

  final SocketService _socket = SocketService();
  final WebRTCService _webrtc = WebRTCService();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socket.connect().then((_) {
      _socket.on('new_private_message', _handleIncomingMessage);
      _socket.on('message_received', _handleIncomingMessage);
      _socket.on('user_typing_start', _handleTypingStart);
      _socket.on('typing_start', _handleTypingStart);
      _socket.on('user_typing_stop', _handleTypingStop);
      _socket.on('typing_stop', _handleTypingStop);
      _socket.on('new_match', _handleNewMatch);
      _socket.on('user_presence_change', _handlePresenceChange);
    }).catchError((_) {});
  }

  void _handleIncomingMessage(dynamic data) {
    if (!mounted || data is! Map) return;
    final convId = data['conversationId']?.toString();
    final text = data['text']?.toString() ?? '';
    final isMine = data['isMine'] == true;

    setState(() {
      final index = _conversations.indexWhere((c) => c.id == convId);
      if (index != -1) {
        final conv = _conversations[index];
        conv.lastMessageText = text;
        conv.lastMessageAt = DateTime.now();
        if (!isMine) {
          conv.unreadCount += 1;
        }
        conv.isTyping = false;
        // Move updated conversation to top
        _conversations.removeAt(index);
        _conversations.insert(0, conv);
      } else {
        // New conversation received -> refresh
        _fetchConversations();
      }
    });
  }

  void _handleTypingStart(dynamic data) {
    if (!mounted || data is! Map) return;
    final convId = data['conversationId']?.toString();
    if (convId == null) return;

    setState(() {
      final index = _conversations.indexWhere((c) => c.id == convId);
      if (index != -1) {
        _conversations[index].isTyping = true;
      }
    });
  }

  void _handleTypingStop(dynamic data) {
    if (!mounted || data is! Map) return;
    final convId = data['conversationId']?.toString();
    if (convId == null) return;

    setState(() {
      final index = _conversations.indexWhere((c) => c.id == convId);
      if (index != -1) {
        _conversations[index].isTyping = false;
      }
    });
  }

  void _handleNewMatch(dynamic _) {
    if (mounted) {
      _fetchData();
    }
  }

  void _handlePresenceChange(dynamic data) {
    if (!mounted || data is! Map) return;
    final userId = data['userId']?.toString();
    final isOnline = data['isOnline'] == true;

    setState(() {
      for (final c in _conversations) {
        if (c.recipientId == userId) {
          c.isOnline = isOnline;
        }
      }
    });
  }

  @override
  void dispose() {
    _socket.off('new_private_message', _handleIncomingMessage);
    _socket.off('message_received', _handleIncomingMessage);
    _socket.off('user_typing_start', _handleTypingStart);
    _socket.off('typing_start', _handleTypingStart);
    _socket.off('user_typing_stop', _handleTypingStop);
    _socket.off('typing_stop', _handleTypingStop);
    _socket.off('new_match', _handleNewMatch);
    _socket.off('user_presence_change', _handlePresenceChange);
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchConversations(),
        _fetchMatches(),
      ]);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not load conversations. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchConversations() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.chats);
      if (res.data is Map && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        final items = list
            .map((item) =>
                ConversationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        // Sort by latest message descending
        items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

        if (mounted) {
          setState(() {
            _conversations = items;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchMatches() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.likes);
      if (res.data is Map && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        final allLikes = list.map((item) => LikeModel.fromJson(item)).toList();
        final matchedOnly = allLikes.where((l) => l.isMatched).toList();

        if (mounted) {
          setState(() {
            _matches = matchedOnly;
          });
        }
      }
    } catch (_) {}
  }

  void _openChatFromConversation(ConversationModel conv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversationId: conv.id,
          recipientId: conv.recipientId,
          recipientName: conv.name,
          recipientPhoto: conv.profilePhoto,
        ),
      ),
    ).then((_) {
      // Clear unread count locally and reload conversations
      setState(() => conv.unreadCount = 0);
      _fetchConversations();
    });
  }

  void _openChatFromMatch(LikeModel match) {
    if (match.conversationId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversationId: match.conversationId!,
            recipientId: match.targetUserId,
            recipientName: match.name,
            recipientPhoto: match.profilePhoto,
          ),
        ),
      ).then((_) => _fetchData());
    }
  }

  Future<void> _startCall(String targetUserId, String name, String photo,
      {required bool isVideo}) async {
    try {
      await _webrtc.initRenderers();
    } catch (_) {}

    await _webrtc.startCall(targetUserId, isVideo: isVideo);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            webrtcService: _webrtc,
            peerName: name,
            peerPhoto: photo,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  String _formatMessageTime(DateTime time) {
    final localTime = time.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inDays == 0 && now.day == localTime.day) {
      return DateFormat('h:mm a').format(localTime);
    } else if (difference.inDays < 2 && (now.day - localTime.day == 1)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(localTime);
    } else {
      return DateFormat('MMM d').format(localTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats & Connections',
          style: AppTypography.displayMedium.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: _fetchData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: CustomScrollView(
                    slivers: [
                      // 1. Matches Tray (Horizontal Row)
                      if (_matches.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.xs,
                            ),
                            child: Text(
                              'Matches (${_matches.length})',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 105,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md),
                              itemCount: _matches.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (ctx, index) {
                                final match = _matches[index];
                                return GestureDetector(
                                  onTap: () => _openChatFromMatch(match),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(2.5),
                                            decoration: const BoxDecoration(
                                              gradient: AppColors.heartGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: AvatarImage(
                                              url: match.profilePhoto,
                                              radius: 28,
                                            ),
                                          ),
                                          if (match.isOnline)
                                            Positioned(
                                              right: 2,
                                              bottom: 2,
                                              child: Container(
                                                width: 13,
                                                height: 13,
                                                decoration: BoxDecoration(
                                                  color: AppColors.likeGreen,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? AppColors.darkBackground
                                                        : Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 68,
                                        child: Text(
                                          match.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: Divider(height: 1)),
                      ],

                      // 2. Header for Conversations
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            'Messages',
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),

                      // 3. Conversations List
                      if (_conversations.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'No Conversations Yet',
                            description:
                                'When you match with peers, your conversations will appear here. Start discovering!',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, index) {
                              final conv = _conversations[index];
                              return _buildConversationTile(conv, isDark);
                            },
                            childCount: _conversations.length,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildConversationTile(ConversationModel conv, bool isDark) {
    final hasUnread = conv.unreadCount > 0;

    return InkWell(
      onTap: () => _openChatFromConversation(conv),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: hasUnread
              ? (isDark
                  ? AppColors.primary.withOpacity(0.08)
                  : AppColors.primary.withOpacity(0.04))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // User Avatar with Online Dot
            Stack(
              children: [
                AvatarImage(url: conv.profilePhoto, radius: 26),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.likeGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBackground
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // Name and Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          conv.name,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatMessageTime(conv.lastMessageAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: hasUnread ? AppColors.primary : Colors.grey,
                          fontWeight: hasUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: conv.isTyping
                            ? Text(
                                'typing...',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Text(
                                conv.lastMessageText.isNotEmpty
                                    ? conv.lastMessageText
                                    : 'Say hello! 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: hasUnread
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.grey,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            conv.unreadCount > 9 ? '9+' : '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quick Call Actions
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.call_outlined, size: 20),
              color: AppColors.primary,
              tooltip: 'Audio Call',
              onPressed: () => _startCall(
                conv.recipientId,
                conv.name,
                conv.profilePhoto,
                isVideo: false,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, size: 22),
              color: AppColors.primary,
              tooltip: 'Video Call',
              onPressed: () => _startCall(
                conv.recipientId,
                conv.name,
                conv.profilePhoto,
                isVideo: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
