import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/network/socket_service.dart';

enum CallState {
  idle,
  outgoing,
  incoming,
  ringing,
  connecting,
  connected,
  ended,
  rejected,
  missed,
  failed
}

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final SocketService _socket = SocketService();
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool isMuted = false;
  bool isVideoOff = false;
  bool isSpeakerOn = true;
  String? currentTargetUserId;
  String? currentCallType; // 'audio' or 'video'
  String? currentCallId;
  CallState callState = CallState.idle;

  Function(CallState)? onCallStateChanged;

  /// Called when an incoming call arrives.
  /// Payload: { callerId, callerName, callerPhoto, callType, offer, callId }
  Function(Map<String, dynamic>)? onIncomingCall;

  Timer? _ringingTimer;

  // Standard public Google STUN servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  bool _listenersRegistered = false;
  bool _renderersInitialized = false;

  Future<void> initRenderers() async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }
    _setupSocketListeners();
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('sounds/ringtone.wav'));
      debugPrint('[Ringtone] Started call ringtone');
    } catch (e) {
      debugPrint('[Ringtone] Play error: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
      debugPrint('[Ringtone] Stopped call ringtone');
    } catch (_) {}
  }

  void _setupSocketListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    // Incoming call event from backend
    _socket.on('incoming_call', (data) {
      debugPrint('[CALL] [SOCKET] incoming_call received: $data');
      final callData = Map<String, dynamic>.from(data);
      final incomingCallId = callData['callId'] as String?;

      // Reject if already in active call
      if (callState == CallState.connected ||
          callState == CallState.outgoing ||
          callState == CallState.ringing ||
          callState == CallState.incoming) {
        final callerId = callData['callerId'] as String?;
        if (callerId != null) {
          debugPrint('[CALL] Rejecting incoming call: already busy in callState $callState');
          _socket.emit('reject_call', {
            'callerId': callerId,
            'callId': incomingCallId,
            'reason': 'busy'
          });
        }
        return;
      }

      currentCallId = incomingCallId;
      currentTargetUserId = callData['callerId']?.toString();
      currentCallType = callData['callType'] as String? ?? 'video';
      _setCallState(CallState.incoming);
      _playRingtone();

      if (onIncomingCall != null) {
        onIncomingCall!(callData);
      }
    });

    // Remote phone started ringing
    _socket.on('call_ringing', (data) {
      debugPrint('[CALL] [SOCKET] call_ringing received');
      if (callState == CallState.outgoing) {
        _setCallState(CallState.ringing);
      }
    });

    // Caller cancelled call while ringing
    _socket.on('call_cancelled', (data) {
      debugPrint('[CALL] [SOCKET] Call cancelled by caller');
      _stopRingtone();
      _handleCallEnd(endedState: CallState.missed);
    });

    // Receiver accepted call -> set remote SDP answer
    _socket.on('call_accepted', (data) async {
      debugPrint('[CALL] [SOCKET] call_accepted received');
      _ringingTimer?.cancel();
      _stopRingtone();
      final answer = data['answer'];
      if (answer != null && _peerConnection != null) {
        try {
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(answer['sdp'], answer['type']),
          );
          _setCallState(CallState.connected);
        } catch (e) {
          debugPrint('[WebRTC] Error setting remote description: $e');
        }
      }
    });

    // Call rejected or ended
    _socket.on('call_rejected', (data) {
      debugPrint('[CALL] [SOCKET] call_rejected received: $data');
      _ringingTimer?.cancel();
      _stopRingtone();
      final reason = (data is Map) ? data['reason'] : null;
      if (reason == 'busy' || reason == 'offline') {
        _handleCallEnd(endedState: CallState.failed);
      } else {
        _handleCallEnd(endedState: CallState.rejected);
      }
    });

    _socket.on('call_ended', (_) {
      debugPrint('[CALL] [SOCKET] call_ended received');
      _ringingTimer?.cancel();
      _stopRingtone();
      _handleCallEnd(endedState: CallState.ended);
    });

    _socket.on('call_timeout', (_) {
      debugPrint('[CALL] [SOCKET] call_timeout received');
      _ringingTimer?.cancel();
      _stopRingtone();
      _handleCallEnd(endedState: CallState.missed);
    });

    // Remote ICE candidate received
    _socket.on('ice_candidate', (data) async {
      final candidateData = data['candidate'];
      if (candidateData != null && _peerConnection != null) {
        try {
          final candidate = RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        } catch (_) {
          // Ignore stale ICE candidate errors
        }
      }
    });

    // Peer media state toggle
    _socket.on('peer_media_state_changed', (_) {});
  }

  void _setCallState(CallState state) {
    callState = state;
    onCallStateChanged?.call(state);
  }

  Future<void> startCall(String targetUserId, {bool isVideo = true}) async {
    if (callState == CallState.connected ||
        callState == CallState.outgoing ||
        callState == CallState.ringing ||
        callState == CallState.incoming) {
      return;
    }

    currentTargetUserId = targetUserId;
    currentCallType = isVideo ? 'video' : 'audio';
    currentCallId =
        'call_${DateTime.now().millisecondsSinceEpoch}_$targetUserId';

    debugPrint('[CALL] startCall: calling $targetUserId ($currentCallType, ID: $currentCallId)');
    _setCallState(CallState.outgoing);
    _playRingtone();

    try {
      await _createPeerConnection();
      await _getUserMedia(isVideo);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _socket.emit('call_user', {
        'targetUserId': targetUserId,
        'callType': currentCallType,
        'callId': currentCallId,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });

      // 30-second ringing timeout for missed call
      _ringingTimer?.cancel();
      _ringingTimer = Timer(const Duration(seconds: 30), () {
        if (callState == CallState.outgoing ||
            callState == CallState.ringing ||
            callState == CallState.connecting) {
          debugPrint('[CALL] Ringing timeout reached (30s)');
          _socket.emit('cancel_call', {
            'targetUserId': targetUserId,
            'callId': currentCallId,
          });
          _socket.emit('call_missed', {
            'targetUserId': targetUserId,
            'callType': currentCallType,
            'callId': currentCallId,
          });
          _handleCallEnd(endedState: CallState.missed);
        }
      });
    } catch (e) {
      debugPrint('[WebRTC] Failed to start call: $e');
      _handleCallEnd(endedState: CallState.failed);
    }
  }

  Future<void> acceptCall(
    String callerId,
    Map<String, dynamic> offerData, {
    bool isVideo = true,
  }) async {
    _ringingTimer?.cancel();
    _stopRingtone();
    currentTargetUserId = callerId;
    currentCallType = isVideo ? 'video' : 'audio';
    currentCallId = offerData['callId'] as String? ?? currentCallId;

    debugPrint('[CALL] acceptCall: answering $callerId ($currentCallType, ID: $currentCallId)');
    _setCallState(CallState.connecting);

    try {
      await _createPeerConnection();
      await _getUserMedia(isVideo);

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerData['sdp'], offerData['type']),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _socket.emit('accept_call', {
        'callerId': callerId,
        'callId': currentCallId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });

      _setCallState(CallState.connected);
    } catch (e) {
      debugPrint('[WebRTC] Failed to accept call: $e');
      _handleCallEnd(endedState: CallState.failed);
    }
  }

  void rejectCall(String callerId) {
    debugPrint('[CALL] rejectCall: declining call from $callerId');
    _ringingTimer?.cancel();
    _stopRingtone();
    _socket.emit('reject_call', {
      'callerId': callerId,
      'callId': currentCallId,
      'reason': 'declined',
    });
    _handleCallEnd(endedState: CallState.rejected);
  }

  void endCall() {
    debugPrint('[CALL] endCall initiated (currentState: $callState)');
    _ringingTimer?.cancel();
    _stopRingtone();
    if (currentTargetUserId != null) {
      if (callState == CallState.outgoing || callState == CallState.ringing) {
        _socket.emit('cancel_call', {
          'targetUserId': currentTargetUserId,
          'callId': currentCallId,
        });
      } else {
        _socket.emit('end_call', {
          'targetUserId': currentTargetUserId,
          'callId': currentCallId,
        });
      }
    }
    _handleCallEnd(endedState: CallState.ended);
  }

  void toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        isMuted = !isMuted;
        audioTrack.enabled = !isMuted;
        if (currentTargetUserId != null) {
          _socket.emit('media_state_toggle', {
            'targetUserId': currentTargetUserId,
            'isMuted': isMuted,
            'isVideoOff': isVideoOff,
          });
        }
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        isVideoOff = !isVideoOff;
        videoTrack.enabled = !isVideoOff;
        if (currentTargetUserId != null) {
          _socket.emit('media_state_toggle', {
            'targetUserId': currentTargetUserId,
            'isMuted': isMuted,
            'isVideoOff': isVideoOff,
          });
        }
      }
    }
  }

  void toggleSpeaker() {
    isSpeakerOn = !isSpeakerOn;
    try {
      Helper.setSpeakerphoneOn(isSpeakerOn);
    } catch (_) {}
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (candidate) {
      if (currentTargetUserId != null && candidate.candidate != null) {
        _socket.emit('ice_candidate', {
          'targetUserId': currentTargetUserId,
          'callId': currentCallId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setCallState(CallState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handleCallEnd(endedState: CallState.ended);
      }
    };
  }

  Future<void> _getUserMedia(bool isVideo) async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': isVideo
          ? {'facingMode': 'user', 'width': 1280, 'height': 720}
          : false,
    };

    _localStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    _localStream!.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
  }

  void _handleCallEnd({CallState endedState = CallState.ended}) {
    _stopRingtone();
    _ringingTimer?.cancel();
    _ringingTimer = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    currentTargetUserId = null;
    currentCallId = null;
    _setCallState(endedState);
    callState = CallState.idle;
  }

  void dispose() {
    _stopRingtone();
    _ringtonePlayer.dispose();
    _handleCallEnd();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _renderersInitialized = false;
  }
}
