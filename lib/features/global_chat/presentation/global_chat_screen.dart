import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _myUserId;
  bool _isSending = false;

  // Reply state
  Map<String, dynamic>? _replyingTo;

  // Edit state
  String? _editingMessageId;
  String? _editingOriginalText;

  final SocketService _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _initGlobalChat();
  }

  Future<void> _initGlobalChat() async {
    _myUserId = await TokenStorage.getUserId();
    await _fetchMessages();

    await _socket.connect();
    _socket.joinGlobalChat();

    _socket.on('new_global_message', _handleNewGlobalMessage);
    _socket.on('global_message_deleted', _handleGlobalMessageDeleted);
    _socket.on('global_message_edited', _handleGlobalMessageEdited);
  }

  void _handleNewGlobalMessage(dynamic data) {
    if (!mounted || data == null) return;
    try {
      final msgMap = Map<String, dynamic>.from(data);
      final msgId = (msgMap['id'] ?? msgMap['_id'])?.toString();
      final sender = msgMap['sender'] ?? {};
      final senderId = (sender['id'] ?? msgMap['senderId'])?.toString();
      if (_myUserId != null && senderId == _myUserId) {
        msgMap['isMine'] = true;
      }
      setState(() {
        final existingIndex = _messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
        if (existingIndex != -1) {
          _messages[existingIndex] = msgMap;
        } else {
          _messages.add(msgMap);
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[GlobalChat] Error handling new message: $e');
    }
  }

  void _handleGlobalMessageDeleted(dynamic data) {
    if (!mounted || data == null) return;
    try {
      final msgId = data['messageId']?.toString();
      if (msgId != null) {
        setState(() {
          _messages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
        });
      }
    } catch (e) {
      debugPrint('[GlobalChat] Error deleting message: $e');
    }
  }

  void _handleGlobalMessageEdited(dynamic data) {
    if (!mounted || data == null) return;
    try {
      final msgId = data['messageId']?.toString();
      final newText = data['text'];
      if (msgId != null && newText != null) {
        setState(() {
          final idx = _messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
          if (idx != -1) {
            _messages[idx] = {
              ..._messages[idx],
              'text': newText,
              'isEdited': true,
            };
          }
        });
      }
    } catch (e) {
      debugPrint('[GlobalChat] Error editing message: $e');
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.globalChatMessages);
      if (res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _messages.clear();
          _messages.addAll(list.map((item) => Map<String, dynamic>.from(item)));
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Edit mode
    if (_editingMessageId != null) {
      await _submitEdit(text);
      return;
    }

    _textController.clear();
    setState(() => _isSending = true);

    try {
      final body = <String, dynamic>{'text': text};
      if (_replyingTo != null) {
        final replyId = _replyingTo!['id'] ?? _replyingTo!['_id'];
        if (replyId != null) body['replyTo'] = replyId.toString();
      }

      final res = await ApiClient().post(ApiEndpoints.globalChatMessages, data: body);
      if (res.data['success'] == true && res.data['data'] != null) {
        final sent = Map<String, dynamic>.from(res.data['data']);
        sent['isMine'] = true;
        sent['createdAt'] ??= DateTime.now().toUtc().toIso8601String();
        final sentId = (sent['id'] ?? sent['_id'])?.toString();
        setState(() {
          if (!_messages.any((m) => (m['id'] ?? m['_id'])?.toString() == sentId)) {
            _messages.add(sent);
          }
          _replyingTo = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be posted. Rate limit may apply.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _submitEdit(String newText) async {
    final msgId = _editingMessageId!;
    setState(() => _isSending = true);
    _textController.clear();
    final prevEditId = _editingMessageId;
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
    });

    try {
      final res = await ApiClient().put(
        ApiEndpoints.globalChatMessage(msgId),
        data: {'text': newText},
      );
      if (res.data['success'] == true) {
        setState(() {
          final idx = _messages.indexWhere((m) => (m['id'] ?? m['_id'])?.toString() == prevEditId?.toString());
          if (idx != -1) {
            _messages[idx] = {
              ..._messages[idx],
              'text': newText,
              'isEdited': true,
            };
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to edit message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final msgId = (msg['id'] ?? msg['_id']).toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await ApiClient().delete(ApiEndpoints.globalChatMessage(msgId));
      if (res.statusCode == 200 || res.data?['success'] == true) {
        setState(() {
          _messages.removeWhere((m) => (m['id'] ?? m['_id'])?.toString() == msgId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete message.')),
        );
      }
    }
  }

  void _startReply(Map<String, dynamic> msg) {
    setState(() {
      _replyingTo = msg;
      _editingMessageId = null;
      _editingOriginalText = null;
    });
    _textController.clear();
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).unfocus();
    });
  }

  void _startEdit(Map<String, dynamic> msg) {
    final msgId = (msg['id'] ?? msg['_id']).toString();
    final currentText = msg['text'] ?? '';
    setState(() {
      _editingMessageId = msgId;
      _editingOriginalText = currentText;
      _replyingTo = null;
    });
    _textController.text = currentText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentText.length),
    );
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
    });
    _textController.clear();
  }

  void _showMessageActions(Map<String, dynamic> msg, bool isMine) {
    final sender = msg['sender'] ?? {};
    final senderName = sender['name'] ?? 'Student';

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Message preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (msg['text'] ?? '').length > 80
                      ? '${(msg['text'] ?? '').substring(0, 80)}...'
                      : (msg['text'] ?? ''),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              // Reply — always available
              _ActionTile(
                icon: Icons.reply_rounded,
                label: isMine ? 'Reply' : 'Reply to $senderName',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              if (isMine) ...[
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.edit_rounded,
                  label: 'Edit Message',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEdit(msg);
                  },
                ),
                const Divider(height: 1),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Message',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socket.off('new_global_message', _handleNewGlobalMessage);
    _socket.off('global_message_deleted', _handleGlobalMessageDeleted);
    _socket.off('global_message_edited', _handleGlobalMessageEdited);
    _socket.leaveGlobalChat();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Global Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ValueListenableBuilder<bool>(
              valueListenable: _socket.isConnectedNotifier,
              builder: (context, connected, child) {
                return Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: connected ? AppColors.accent : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connected ? 'Campus Lounge • Live' : 'Connecting...',
                      style: AppTypography.labelSmall.copyWith(
                        color: connected ? AppColors.accent : Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMessages),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No messages in campus chat yet.',
                              style: AppTypography.titleMedium.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to say something to everyone!',
                              style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, index) {
                            final msg = _messages[index];
                            final sender = msg['sender'] ?? {};
                            final senderId = sender['id']?.toString() ?? msg['senderId']?.toString();
                            final isMine = msg['isMine'] == true ||
                                (_myUserId != null && senderId == _myUserId);

                            return GestureDetector(
                              onLongPress: () => _showMessageActions(msg, isMine),
                              child: _buildMessageBubble(msg, sender, isMine, isDark),
                            );
                          },
                        ),
                      ),
          ),

          // ── Reply / Edit preview bar ──
          if (_replyingTo != null) _buildReplyBar(isDark),
          if (_editingMessageId != null) _buildEditBar(isDark),

          // ── Message Composer ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                  top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Cancel edit icon
                  if (_editingMessageId != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.orange),
                      onPressed: _cancelEdit,
                      tooltip: 'Cancel editing',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null
                            ? 'Edit message...'
                            : 'Share a thought with campus...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _editingMessageId != null ? Icons.check_rounded : Icons.send_rounded,
                            color: AppColors.primary,
                          ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reply preview bar ──
  Widget _buildReplyBar(bool isDark) {
    final replyText = (_replyingTo?['text'] ?? '') as String;
    final replySender = (_replyingTo?['sender']?['name'] ?? 'Student') as String;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      color: isDark
          ? AppColors.primary.withOpacity(0.15)
          : AppColors.primary.withOpacity(0.07),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to $replySender',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(
                  replyText.length > 60 ? '${replyText.substring(0, 60)}…' : replyText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  // ── Edit mode bar ──
  Widget _buildEditBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      color: isDark
          ? Colors.orange.withOpacity(0.15)
          : Colors.orange.withOpacity(0.07),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editing message',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                const SizedBox(height: 2),
                Text(
                  (_editingOriginalText ?? '').length > 60
                      ? '${(_editingOriginalText ?? '').substring(0, 60)}…'
                      : (_editingOriginalText ?? ''),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: _cancelEdit,
          ),
        ],
      ),
    );
  }

  // ── Message bubble ──
  Widget _buildMessageBubble(
      Map<String, dynamic> msg, Map<String, dynamic> sender, bool isMine, bool isDark) {
    DateTime? dt;
    if (msg['createdAt'] != null) {
      if (msg['createdAt'] is DateTime) {
        dt = (msg['createdAt'] as DateTime).toLocal();
      } else {
        dt = DateTime.tryParse(msg['createdAt'].toString())?.toLocal();
      }
    }
    dt ??= DateTime.now();

    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    String timeStr;
    if (isToday) {
      timeStr = DateFormat('h:mm a').format(dt);
    } else if (isYesterday) {
      timeStr = 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    } else {
      timeStr = DateFormat('MMM d, h:mm a').format(dt);
    }
    final isEdited = msg['isEdited'] == true;

    // Find quoted reply message if any
    final replyToRaw = msg['replyTo'];
    String? quotedText;
    String? quotedSender;
    if (replyToRaw != null) {
      if (replyToRaw is Map) {
        quotedText = replyToRaw['text'] as String?;
        final replyToId = replyToRaw['senderId'];
        if (replyToId != null) {
          final found = _messages.firstWhere(
            (m) {
              final s = m['sender'];
              return s != null && ((s['id'] ?? s['_id'])?.toString() == replyToId.toString());
            },
            orElse: () => {},
          );
          quotedSender = found.isNotEmpty ? (found['sender']?['name'] ?? 'Student') : 'Student';
        }
      } else {
        final found = _messages.firstWhere(
          (m) => (m['id'] ?? m['_id'])?.toString() == replyToRaw.toString(),
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          quotedText = found['text'] as String?;
          quotedSender = found['sender']?['name'] ?? 'Student';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            AvatarImage(url: sender['profilePhoto'], radius: 18),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sender['name'] ?? 'Student',
                        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (sender['username'] != null &&
                          sender['username'].toString().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '@${sender['username']}',
                          style: AppTypography.labelSmall
                              .copyWith(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.md),
                      topRight: const Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(isMine ? AppRadius.md : 0),
                      bottomRight: Radius.circular(isMine ? 0 : AppRadius.md),
                    ),
                    border: isMine || isDark ? null : Border.all(color: AppColors.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // ── Quoted reply ──
                      if (quotedText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white.withOpacity(0.18)
                                : (isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.06)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isMine ? Colors.white70 : AppColors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (quotedSender != null)
                                Text(
                                  quotedSender,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isMine ? Colors.white70 : AppColors.primary,
                                  ),
                                ),
                              Text(
                                quotedText.length > 80
                                    ? '${quotedText.substring(0, 80)}…'
                                    : quotedText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMine ? Colors.white60 : Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                      // ── Message text ──
                      Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isMine
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          fontSize: 14.5,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // ── Time + edited ──
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEdited) ...[
                            Text(
                              'edited',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontStyle: FontStyle.italic,
                                color: isMine ? Colors.white60 : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isMine ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widget for action sheet tiles ──
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
