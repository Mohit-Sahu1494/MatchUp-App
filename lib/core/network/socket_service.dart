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

  bool get isConnected => _socket?.connected ?? false;

  SocketService._internal();

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      isConnectedNotifier.value = true;
      return;
    }

    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return;

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    final completer = Completer<void>();

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] connected to MatchUp real-time gateway');
      isConnectedNotifier.value = true;
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SOCKET] disconnected from gateway');
      isConnectedNotifier.value = false;
    });

    _socket!.onConnectError((err) {
      debugPrint('[SOCKET] connection error: $err');
      isConnectedNotifier.value = false;
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onReconnect((_) {
      debugPrint('[SOCKET] reconnected to gateway');
      isConnectedNotifier.value = true;
    });

    // Wait up to 3 seconds for initial connection handshake
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
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
    emit('typing_start', {'conversationId': conversationId, 'recipientId': recipientId});
  }

  void stopTyping(String conversationId, String recipientId) {
    emit('typing_stop', {'conversationId': conversationId, 'recipientId': recipientId});
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
    isConnectedNotifier.value = false;
  }
}
