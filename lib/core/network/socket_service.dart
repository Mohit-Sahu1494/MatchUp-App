import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../storage/token_storage.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  io.Socket? _socket;
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  // Persistent listener registry so listeners survive reconnects & socket recreation
  final Map<String, List<Function(dynamic)>> _listeners = {};

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  SocketService._internal();

  Future<void> connect() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[SOCKET] Connect skipped: no auth token found');
      return;
    }

    if (_socket != null && _socket!.connected) {
      isConnectedNotifier.value = true;
      return;
    }

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    final completer = Completer<void>();
    final socketUrl = ApiEndpoints.socketUrl;

    debugPrint('[SOCKET] Connecting to real-time gateway: $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setReconnectionAttempts(15)
          .setAuth({'token': token})
          .setQuery({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] connected (id: ${_socket?.id}) to $socketUrl');
      isConnectedNotifier.value = true;
      _reapplyListeners();
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SOCKET] disconnected: $reason');
      isConnectedNotifier.value = false;
    });

    _socket!.onConnectError((err) {
      debugPrint('[SOCKET] connection error: $err');
      isConnectedNotifier.value = false;
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onReconnect((attempt) {
      debugPrint('[SOCKET] reconnected on attempt #$attempt (id: ${_socket?.id})');
      isConnectedNotifier.value = true;
      _reapplyListeners();
    });

    _socket!.onReconnectError((err) {
      debugPrint('[SOCKET] reconnect error: $err');
    });

    // Reapply any pre-registered listeners
    _reapplyListeners();

    // Wait up to 3.5 seconds for initial connection handshake
    try {
      await completer.future.timeout(const Duration(milliseconds: 3500));
    } catch (_) {}
  }

  void _reapplyListeners() {
    if (_socket == null) return;
    _listeners.forEach((event, handlers) {
      _socket!.off(event);
      for (final handler in handlers) {
        _socket!.on(event, (data) {
          _logEvent(event, data);
          handler(data);
        });
      }
    });
  }

  void _logEvent(String event, dynamic data) {
    if (event == 'incoming_call') {
      debugPrint('[SOCKET] incoming_call received: ${data is Map ? data['callId'] : ''}');
    } else if (event == 'new_private_message' || event == 'message_received') {
      debugPrint('[SOCKET] message_received: ${data is Map ? (data['messageId'] ?? data['id']) : ''}');
    } else if (event == 'typing_start' || event == 'user_typing_start') {
      debugPrint('[SOCKET] typing_start in conv: ${data is Map ? data['conversationId'] : ''}');
    } else if (event == 'typing_stop' || event == 'user_typing_stop') {
      debugPrint('[SOCKET] typing_stop in conv: ${data is Map ? data['conversationId'] : ''}');
    }
  }

  void on(String event, Function(dynamic) handler) {
    final list = _listeners.putIfAbsent(event, () => []);
    if (!list.contains(handler)) {
      list.add(handler);
    }
    _socket?.on(event, (data) {
      _logEvent(event, data);
      handler(data);
    });
  }

  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _listeners[event]?.remove(handler);
      _socket?.off(event, handler);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  void emit(String event, dynamic data) {
    if (_socket != null) {
      debugPrint('[SOCKET] emit: $event');
      _socket!.emit(event, data);
    } else {
      debugPrint('[SOCKET] emit dropped (socket is null): $event');
    }
  }

  void joinConversation(String conversationId) {
    emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    emit('leave_conversation', conversationId);
  }

  void startTyping(String conversationId, String recipientId) {
    emit('typing_start', {
      'conversationId': conversationId,
      'recipientId': recipientId,
    });
  }

  void stopTyping(String conversationId, String recipientId) {
    emit('typing_stop', {
      'conversationId': conversationId,
      'recipientId': recipientId,
    });
  }

  void joinGlobalChat() {
    emit('join_global_chat', {});
  }

  void leaveGlobalChat() {
    emit('leave_global_chat', {});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _listeners.clear();
    isConnectedNotifier.value = false;
    debugPrint('[SOCKET] socket disconnected and disposed');
  }
}
