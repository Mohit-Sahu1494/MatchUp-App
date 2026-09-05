import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../models/message_model.dart';
import '../widgets/image_viewer_modal.dart';
import '../widgets/video_player_modal.dart';
import '../../gifts/presentation/gift_modal_sheet.dart';
import '../../calling/services/webrtc_service.dart';
import '../../calling/presentation/call_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String recipientPhoto;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhoto,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  bool _isUploading = false;
  String? _myUserId;
  MessageModel? _replyingTo;
  Timer? _typingDebounce;
  bool _typingSent = false;

  final SocketService _socket = SocketService();
  final WebRTCService _webrtc = WebRTCService();

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // 1. Get my userId FIRST so formatMessage works correctly
    _myUserId = await TokenStorage.getUserId();

    // 2. Connect socket and join conversation room
    await _socket.connect();
    _socket.joinConversation(widget.conversationId);

    // 3. Register ALL socket listeners before fetching (avoid race conditions)
    _socket.on('new_private_message', _handleIncomingMessage);
    _socket.on('message_edited', _handleMessageEdited);
    _socket.on('message_deleted', _handleMessageDeleted);
    _socket.on('user_typing_start', _handleTypingStart);
    _socket.on('user_typing_stop', _handleTypingStop);

    // 4. Now load history
    await _fetchMessages();

    // 5. Init WebRTC renderers (background, non-blocking)
    _webrtc.initRenderers().catchError((_) {});
  }

  void _handleIncomingMessage(dynamic data) {
    if (!mounted) return;
    try {
      final newMsg = MessageModel.fromJson(Map<String, dynamic>.from(data),
          currentUserId: _myUserId);
      if (newMsg.conversationId == widget.conversationId) {
        setState(() {
          // Deduplicate by message ID
          final existingIndex = _messages.indexWhere((m) => m.id == newMsg.id);
          if (existingIndex != -1) {
            _messages[existingIndex] = newMsg;
          } else {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[Chat] Error handling incoming message: $e');
    }
  }

  void _handleMessageEdited(dynamic data) {
    if (!mounted) return;
    try {
      final updatedMsg = MessageModel.fromJson(Map<String, dynamic>.from(data),
          currentUserId: _myUserId);
      if (updatedMsg.conversationId == widget.conversationId) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updatedMsg.id);
          if (index != -1) {
            _messages[index] = updatedMsg;
          }
        });
      }
    } catch (e) {
      debugPrint('[Chat] Error updating edited message: $e');
    }
  }

  void _handleMessageDeleted(dynamic data) {
    if (!mounted) return;
    try {
      final msgId = data['messageId'];
      final convId = data['conversationId'];
      if (convId == widget.conversationId && msgId != null) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == msgId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              text: 'This message was deleted',
              isDeletedForEveryone: true,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[Chat] Error updating deleted message: $e');
    }
  }

  void _handleTypingStart(dynamic data) {
    if (data['conversationId'] == widget.conversationId && mounted) {
      setState(() => _isTyping = true);
    }
  }

  void _handleTypingStop(dynamic data) {
    if (data['conversationId'] == widget.conversationId && mounted) {
      setState(() => _isTyping = false);
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await ApiClient()
          .get(ApiEndpoints.chatMessages(widget.conversationId));
      if (res.data['success'] == true) {
        final List list = res.data['data']['messages'] ?? [];
        setState(() {
          _messages.clear();
          _messages.addAll(list
              .map((m) => MessageModel.fromJson(m, currentUserId: _myUserId)));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(
      {String? text,
      String mediaType = 'text',
      Map<String, dynamic>? giftData}) async {
    final msgText = text ?? _messageController.text.trim();
    if (msgText.isEmpty && giftData == null) return;

    final replyId = _replyingTo?.id;

    if (text == null) {
      _messageController.clear();
      setState(() => _replyingTo = null);
    }

    _stopTyping();

    try {
      final res = await ApiClient().post(ApiEndpoints.sendMessage, data: {
        'conversationId': widget.conversationId,
        'text': msgText,
        'mediaType': mediaType,
        'giftData': giftData,
        'replyToMessageId': replyId,
      });

      if (res.data['success'] == true) {
        final sentMsg =
            MessageModel.fromJson(res.data['data'], currentUserId: _myUserId);
        setState(() {
          if (!_messages.any((m) => m.id == sentMsg.id)) {
            _messages.add(sentMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[Send Error] $e');
    }
  }

  /// Pick an image or video and upload it to the backend, then send as a message.
  Future<void> _uploadAndSendMedia({required ImageSource source, bool video = false}) async {
    try {
      final picker = ImagePicker();
      XFile? pickedFile;
      if (video) {
        pickedFile = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
      } else {
        pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      }
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final fileName = pickedFile.name;
      final mimeType = video ? 'video/mp4' : 'image/jpeg';

      // Upload to /chats/upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final uploadRes = await ApiClient().dio.post(
        ApiEndpoints.chatUpload,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (uploadRes.data['success'] != true) {
        throw Exception(uploadRes.data['message'] ?? 'Upload failed');
      }

      final uploadData = uploadRes.data['data'];
      final mediaUrl = uploadData['url'] as String;
      final mediaType = uploadData['mediaType'] as String;
      final thumbnailUrl = (uploadData['thumbnailUrl'] ?? '') as String;
      final duration = (uploadData['duration'] ?? 0) as int;
      final remoteFileName = (uploadData['fileName'] ?? fileName) as String;

      // Send message with media fields
      final replyId = _replyingTo?.id;
      setState(() => _replyingTo = null);
      _stopTyping();

      final res = await ApiClient().post(ApiEndpoints.sendMessage, data: {
        'conversationId': widget.conversationId,
        'text': '',
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'fileName': remoteFileName,
        'replyToMessageId': replyId,
      });

      if (res.data['success'] == true) {
        final sentMsg = MessageModel.fromJson(res.data['data'], currentUserId: _myUserId);
        setState(() {
          if (!_messages.any((m) => m.id == sentMsg.id)) {
            _messages.add(sentMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[MediaUpload] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, 'Failed to send media'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Show a bottom sheet to choose image/video source.
  void _showMediaPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                ),
                title: const Text('Photo from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadAndSendMedia(source: ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadAndSendMedia(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.videocam_outlined, color: Colors.white, size: 20),
                ),
                title: const Text('Video from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadAndSendMedia(source: ImageSource.gallery, video: true);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.video_camera_back_outlined, color: Colors.white, size: 20),
                ),
                title: const Text('Record a Video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadAndSendMedia(source: ImageSource.camera, video: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEditMessage(MessageModel message) async {
    final editController = TextEditingController(text: message.text);
    final editedText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Edit your message...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (editedText == null || editedText.isEmpty || editedText == message.text) {
      return;
    }

    try {
      final res = await ApiClient().put(
        '${ApiEndpoints.chats}/messages/${message.id}',
        data: {'text': editedText},
      );

      if (res.data['success'] == true) {
        final updated =
            MessageModel.fromJson(res.data['data'], currentUserId: _myUserId);
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = updated;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, 'Failed to edit message'))),
        );
      }
    }
  }

  Future<void> _handleDeleteMessage(MessageModel message) async {
    final isMe = message.senderId == _myUserId || message.isMine;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Choose how you want to delete this message:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'me'),
            child: const Text('Delete for Me'),
          ),
          if (isMe)
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.skipRed),
              onPressed: () => Navigator.pop(ctx, 'everyone'),
              child: const Text('Delete for Everyone'),
            ),
        ],
      ),
    );

    if (action == null) return;

    try {
      if (action == 'me') {
        await ApiClient()
            .delete('${ApiEndpoints.chats}/messages/${message.id}');
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      } else if (action == 'everyone') {
        final res = await ApiClient()
            .delete('${ApiEndpoints.chats}/messages/${message.id}/everyone');
        if (res.data['success'] == true) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                text: 'This message was deleted',
                isDeletedForEveryone: true,
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, 'Failed to delete message'))),
        );
      }
    }
  }

  String _apiErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) return data['message'];
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return 'Server timed out. Please try again.';
      }
    }
    return fallback;
  }

  void _showMessageOptions(MessageModel message) {
    final isMe = message.senderId == _myUserId || message.isMine;
    final isDeleted = message.isDeletedForEveryone;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.reply, color: AppColors.primary),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading:
                      const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleEditMessage(message);
                  },
                ),
            ],
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.skipRed),
              title: const Text('Delete Message',
                  style: TextStyle(color: AppColors.skipRed)),
              onTap: () {
                Navigator.pop(ctx);
                _handleDeleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startCall({required bool isVideo}) async {
    await _webrtc.startCall(widget.recipientId, isVideo: isVideo);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            webrtcService: _webrtc,
            peerName: widget.recipientName,
            peerPhoto: widget.recipientPhoto,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _socket.off('new_private_message', _handleIncomingMessage);
    _socket.off('message_edited', _handleMessageEdited);
    _socket.off('message_deleted', _handleMessageDeleted);
    _socket.off('user_typing_start', _handleTypingStart);
    _socket.off('user_typing_stop', _handleTypingStop);
    _stopTyping();
    _typingDebounce?.cancel();
    _socket.leaveConversation(widget.conversationId);
    _messageController.dispose();
    _scrollController.dispose();
    // Note: _webrtc.dispose() is handled by MainBottomNav's singleton
    // Only dispose renderers if this screen owns a local webrtc instance
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarImage(url: widget.recipientPhoto, radius: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipientName,
                      style: AppTypography.titleMedium.copyWith(fontSize: 16)),
                  Text(
                    _isTyping ? 'typing...' : 'Encrypted Chat 🔒',
                    style: AppTypography.labelSmall.copyWith(
                      color: _isTyping ? AppColors.primary : AppColors.accent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Audio Call WebRTC
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () => _startCall(isVideo: false),
          ),
          // Video Call WebRTC
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => _startCall(isVideo: true),
          ),
          // Send Virtual Gift
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: AppColors.warning),
            onPressed: () {
              GiftModalSheet.show(
                context,
                receiverId: widget.recipientId,
                receiverName: widget.recipientName,
                onGiftSent: (gift) {
                  _sendMessage(
                    text: 'Sent a virtual gift: ${gift.icon} ${gift.name}',
                    mediaType: 'gift',
                    giftData: {
                      'code': gift.code,
                      'name': gift.name,
                      'icon': gift.icon,
                      'pointValue': gift.pointValue,
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // End-to-end encryption banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 4, horizontal: AppSpacing.md),
            color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Messages are encrypted with AES-256-GCM',
                  style: AppTypography.labelSmall
                      .copyWith(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hello to ${widget.recipientName}! 👋',
                          style: AppTypography.bodyMedium
                              .copyWith(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _myUserId || msg.isMine;
                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(msg),
                            child: _buildMessageBubble(msg, isMe, isDark),
                          );
                        },
                      ),
          ),

          // Typing status banner
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.recipientName} is typing...',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),

          // Quoted Reply Preview Bar
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              color: isDark ? AppColors.darkSurface : Colors.grey[100],
              child: Row(
                children: [
                  Container(width: 3, height: 32, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingTo!.senderId == _myUserId ? 'You' : widget.recipientName}',
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _replyingTo!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall
                              .copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Message Input Toolbar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                  top: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Media attach button
                  if (_isUploading)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                      tooltip: 'Attach photo or video',
                      onPressed: _showMediaPickerOptions,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTypingChanged,
                      decoration: const InputDecoration(
                        hintText: 'Type an encrypted message...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _isUploading ? null : () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTypingChanged(String value) {
    _typingDebounce?.cancel();
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_typingSent) {
      _socket.startTyping(widget.conversationId, widget.recipientId);
      _typingSent = true;
    }
    _typingDebounce = Timer(const Duration(seconds: 1), _stopTyping);
  }

  void _stopTyping() {
    _typingDebounce?.cancel();
    if (_typingSent) {
      _socket.stopTyping(widget.conversationId, widget.recipientId);
      _typingSent = false;
    }
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe, bool isDark) {
    final isDeleted = msg.isDeletedForEveryone;
    final hasMedia = msg.mediaUrl.isNotEmpty && !isDeleted;
    final isImageMsg = msg.mediaType == 'image';
    final isVideoMsg = msg.mediaType == 'video';
    final isGiftMsg = msg.mediaType == 'gift';

    // For media-only bubbles, no horizontal padding on the image side
    final EdgeInsets bubblePadding = hasMedia && msg.text.isEmpty
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isDeleted
              ? (isDark ? Colors.grey[850] : Colors.grey[200])
              : isMe
                  ? AppColors.primary
                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMe ? AppRadius.md : 0),
            bottomRight: Radius.circular(isMe ? 0 : AppRadius.md),
          ),
          border:
              isMe || isDark ? null : Border.all(color: AppColors.lightBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMe ? AppRadius.md : 0),
            bottomRight: Radius.circular(isMe ? 0 : AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // ── IMAGE bubble ──────────────────────────────────────────
              if (hasMedia && isImageMsg)
                GestureDetector(
                  onTap: () => ImageViewerModal.show(context, imageUrl: msg.mediaUrl),
                  child: CachedNetworkImage(
                    imageUrl: msg.mediaUrl,
                    width: MediaQuery.of(context).size.width * 0.7,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image, size: 40, color: Colors.white54),
                    ),
                  ),
                ),

              // ── VIDEO bubble ──────────────────────────────────────────
              if (hasMedia && isVideoMsg)
                GestureDetector(
                  onTap: () => VideoPlayerModal.show(context,
                      videoUrl: msg.mediaUrl,
                      title: msg.fileName.isNotEmpty ? msg.fileName : 'Video'),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Thumbnail or fallback
                      msg.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: msg.thumbnailUrl,
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: 180,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 180,
                                color: Colors.black,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 180,
                                width: double.infinity,
                                color: Colors.black87,
                              ),
                            )
                          : Container(
                              height: 180,
                              width: MediaQuery.of(context).size.width * 0.7,
                              color: Colors.black87,
                            ),
                      // Play button overlay
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                      ),
                      // Duration badge
                      if (msg.duration > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(msg.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // ── GIFT bubble ───────────────────────────────────────────
              if (hasMedia && isGiftMsg && msg.giftData != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.giftData!['icon'] ?? '🎁',
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.giftData!['name'] ?? 'Gift',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.white : AppColors.lightTextPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${msg.giftData!['pointValue'] ?? ''} pts',
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ── Text / caption / deleted placeholder ─────────────────
              Padding(
                padding: bubblePadding.copyWith(
                  top: hasMedia ? 6 : bubblePadding.top,
                  bottom: bubblePadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Quoted Reply Preview inside bubble
                    if (msg.replyTo != null && !isDeleted) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.black.withOpacity(0.15)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          msg.replyTo!.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isMe ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],

                    // Message text / deleted placeholder
                    if (isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.block, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'This message was deleted',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                                fontSize: 13),
                          ),
                        ],
                      )
                    else if (msg.text.isNotEmpty && !isGiftMsg)
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          fontSize: 15,
                        ),
                      ),

                    const SizedBox(height: 3),

                    // Timestamp and read/edited status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isEdited && !isDeleted) ...[
                          Text(
                            '(edited) ',
                            style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white60 : Colors.grey),
                          ),
                        ],
                        Text(
                          DateFormat('hh:mm a').format(msg.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        if (isMe && !isDeleted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.status == 'read' ? Icons.done_all : Icons.done,
                            size: 13,
                            color: msg.status == 'read'
                                ? AppColors.accent
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
