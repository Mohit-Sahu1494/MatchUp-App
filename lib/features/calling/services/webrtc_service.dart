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
  Function(Map<String, dynamic>)? onIncomingCall;

  // Standard public Google STUN servers (TURN credentials can be injected via env)
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Incoming call event
    _socket.on('incoming_call', (data) {
      if (onIncomingCall != null) {
        onIncomingCall!(Map<String, dynamic>.from(data));
      }
    });

    // Receiver accepted call -> set remote description
    _socket.on('call_accepted', (data) async {
      final answer = data['answer'];
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      onCallStateChanged?.call(CallState.connected);
    });

    // Call rejected or ended
    _socket.on('call_rejected', (_) => _handleCallEnd());
    _socket.on('call_ended', (_) => _handleCallEnd());

    // Remote ICE candidate received
    _socket.on('ice_candidate', (data) async {
      final candidateData = data['candidate'];
      if (candidateData != null && _peerConnection != null) {
        final candidate = RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  Future<void> startCall(String targetUserId, {bool isVideo = true}) async {
    currentTargetUserId = targetUserId;
    currentCallType = isVideo ? 'video' : 'audio';

    await _createPeerConnection();
    await _getUserMedia(isVideo);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Dispatch signaling offer via Socket.IO
    _socket.emit('call_user', {
      'targetUserId': targetUserId,
      'callType': currentCallType,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    onCallStateChanged?.call(CallState.outgoing);
  }

  Future<void> acceptCall(String callerId, Map<String, dynamic> offerData, {bool isVideo = true}) async {
    currentTargetUserId = callerId;
    currentCallType = isVideo ? 'video' : 'audio';

    await _createPeerConnection();
    await _getUserMedia(isVideo);

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerData['sdp'], offerData['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Dispatch answer via Socket.IO
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
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        isVideoOff = !isVideoOff;
        videoTrack.enabled = !isVideoOff;
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
      if (currentTargetUserId != null) {
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
  }

  Future<void> _getUserMedia(bool isVideo) async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': isVideo ? {'facingMode': 'user', 'width': 1280, 'height': 720} : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
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
