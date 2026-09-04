import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/network/socket_service.dart';

enum CallState { idle, outgoing, incoming, connected, ended }

class WebRTCService {
  final SocketService _socket = SocketService();

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

  Function(CallState)? onCallStateChanged;

  /// Called when an incoming call arrives.
  /// Payload: { callerId, callerName, callerPhoto, callType, offer }
  Function(Map<String, dynamic>)? onIncomingCall;

  // Standard public Google STUN servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  bool _listenersRegistered = false;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    // Incoming call event — notify UI to show accept/reject dialog
    _socket.on('incoming_call', (data) {
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
      onCallStateChanged?.call(CallState.incoming);
    });

    // Receiver accepted call → set remote SDP answer
    _socket.on('call_accepted', (data) async {
      final answer = data['answer'];
      if (answer != null && _peerConnection != null) {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        onCallStateChanged?.call(CallState.connected);
      }
    });

    // Call rejected or ended
    _socket.on('call_rejected', (_) => _handleCallEnd());
    _socket.on('call_ended', (_) => _handleCallEnd());

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
        } catch (e) {
          // Ignore stale ICE candidates
        }
      }
    });

    // Peer muted/video toggled
    _socket.on('peer_media_state_changed', (data) {
      // Can be exposed via a notifier if needed in UI
    });
  }

  Future<void> startCall(String targetUserId, {bool isVideo = true}) async {
    currentTargetUserId = targetUserId;
    currentCallType = isVideo ? 'video' : 'audio';

    await _createPeerConnection();
    await _getUserMedia(isVideo);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket.emit('call_user', {
      'targetUserId': targetUserId,
      'callType': currentCallType,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    onCallStateChanged?.call(CallState.outgoing);
  }

  Future<void> acceptCall(
    String callerId,
    Map<String, dynamic> offerData, {
    bool isVideo = true,
  }) async {
    currentTargetUserId = callerId;
    currentCallType = isVideo ? 'video' : 'audio';

    await _createPeerConnection();
    await _getUserMedia(isVideo);

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerData['sdp'], offerData['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket.emit('accept_call', {
      'callerId': callerId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    onCallStateChanged?.call(CallState.connected);
  }

  void rejectCall(String callerId) {
    _socket.emit('reject_call', {'callerId': callerId, 'reason': 'declined'});
    _handleCallEnd();
  }

  void endCall() {
    if (currentTargetUserId != null) {
      _socket.emit('end_call', {'targetUserId': currentTargetUserId});
    }
    _handleCallEnd();
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
        onCallStateChanged?.call(CallState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handleCallEnd();
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

  void _handleCallEnd() {
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
    onCallStateChanged?.call(CallState.ended);
  }

  void dispose() {
    _handleCallEnd();
    localRenderer.dispose();
    remoteRenderer.dispose();
  }
}
