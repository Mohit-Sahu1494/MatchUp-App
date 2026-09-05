import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class CallScreen extends StatefulWidget {
  final WebRTCService webrtcService;
  final String peerName;
  final String peerPhoto;
  final bool isVideo;

  /// For incoming calls — pass the raw offer data to accept
  final Map<String, dynamic>? incomingCallData;

  const CallScreen({
    super.key,
    required this.webrtcService,
    required this.peerName,
    required this.peerPhoto,
    this.isVideo = true,
    this.incomingCallData,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  CallState _callState = CallState.idle;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    widget.webrtcService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() => _callState = state);
        if (state == CallState.connected) {
          _startDurationTimer();
        } else if (state == CallState.ended ||
            state == CallState.rejected ||
            state == CallState.missed ||
            state == CallState.failed) {
          _durationTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    };

    // Determine initial state
    if (widget.incomingCallData != null) {
      // Incoming call — show accept/reject UI
      setState(() => _callState = CallState.incoming);
    } else {
      // Outgoing call already started by caller
      setState(() => _callState = CallState.outgoing);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getCallStatusText() {
    switch (_callState) {
      case CallState.outgoing:
      case CallState.ringing:
        return 'Calling...';
      case CallState.incoming:
        return 'Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return 'Connected • ${_formatDuration(_callDurationSeconds)}';
      case CallState.rejected:
        return 'Call declined';
      case CallState.missed:
        return 'No answer';
      case CallState.failed:
        return 'Call failed';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }

  Future<void> _acceptCall() async {
    final data = widget.incomingCallData!;
    final callerId = data['callerId'] as String;
    final offer = data['offer'] as Map<String, dynamic>;
    final isVideo = (data['callType'] ?? 'video') == 'video';

    // Init renderers if not done
    try {
      await widget.webrtcService.initRenderers();
    } catch (_) {}

    await widget.webrtcService.acceptCall(callerId, offer, isVideo: isVideo);
  }

  void _rejectCall() {
    final callerId = widget.incomingCallData?['callerId'] as String?;
    if (callerId != null) {
      widget.webrtcService.rejectCall(callerId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Remote Video or Audio Background ──
            if (widget.isVideo && _callState == CallState.connected)
              RTCVideoView(
                widget.webrtcService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _buildAudioAvatarView(),

            // ── Local Video (PiP) ──
            if (widget.isVideo &&
                _callState == CallState.connected &&
                !widget.webrtcService.isVideoOff)
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    color: Colors.black54,
                    child: RTCVideoView(
                      widget.webrtcService.localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // ── Top Header ──
            Positioned(
              top: AppSpacing.xl,
              left: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: AppTypography.displayMedium
                        .copyWith(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _callState == CallState.connected
                              ? AppColors.likeGreen
                              : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getCallStatusText(),
                        style: AppTypography.bodyMedium
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── INCOMING CALL UI — Accept / Reject ──
            if (_callState == CallState.incoming)
              Positioned(
                bottom: AppSpacing.xxl,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reject
                        Column(
                          children: [
                            _buildCircleButton(
                              icon: Icons.call_end,
                              color: AppColors.skipRed,
                              iconColor: Colors.white,
                              size: 64,
                              onTap: _rejectCall,
                            ),
                            const SizedBox(height: 8),
                            const Text('Decline',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        // Accept
                        Column(
                          children: [
                            _buildCircleButton(
                              icon: widget.isVideo
                                  ? Icons.videocam
                                  : Icons.phone,
                              color: AppColors.likeGreen,
                              iconColor: Colors.white,
                              size: 64,
                              onTap: _acceptCall,
                            ),
                            const SizedBox(height: 8),
                            const Text('Accept',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── ACTIVE CALL Controls ──
            if (_callState == CallState.outgoing ||
                _callState == CallState.connected)
              Positioned(
                bottom: AppSpacing.xxl,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute
                    _buildCircleButton(
                      icon: widget.webrtcService.isMuted
                          ? Icons.mic_off
                          : Icons.mic,
                      color: widget.webrtcService.isMuted
                          ? Colors.white
                          : Colors.white24,
                      iconColor: widget.webrtcService.isMuted
                          ? Colors.black
                          : Colors.white,
                      onTap: () => setState(
                          () => widget.webrtcService.toggleMute()),
                    ),

                    // Speaker
                    _buildCircleButton(
                      icon: widget.webrtcService.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_down,
                      color: widget.webrtcService.isSpeakerOn
                          ? Colors.white
                          : Colors.white24,
                      iconColor: widget.webrtcService.isSpeakerOn
                          ? Colors.black
                          : Colors.white,
                      onTap: () => setState(
                          () => widget.webrtcService.toggleSpeaker()),
                    ),

                    // Camera toggle (video only)
                    if (widget.isVideo) ...[
                      _buildCircleButton(
                        icon: widget.webrtcService.isVideoOff
                            ? Icons.videocam_off
                            : Icons.videocam,
                        color: widget.webrtcService.isVideoOff
                            ? Colors.white
                            : Colors.white24,
                        iconColor: widget.webrtcService.isVideoOff
                            ? Colors.black
                            : Colors.white,
                        onTap: () => setState(
                            () => widget.webrtcService.toggleVideo()),
                      ),
                      _buildCircleButton(
                        icon: Icons.switch_camera,
                        color: Colors.white24,
                        iconColor: Colors.white,
                        onTap: () => widget.webrtcService.switchCamera(),
                      ),
                    ],

                    // End / Hang up
                    _buildCircleButton(
                      icon: Icons.call_end,
                      color: AppColors.skipRed,
                      iconColor: Colors.white,
                      onTap: () => widget.webrtcService.endCall(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioAvatarView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 72,
            backgroundImage: widget.peerPhoto.isNotEmpty
                ? NetworkImage(widget.peerPhoto)
                : null,
            backgroundColor: Colors.grey.shade800,
            child: widget.peerPhoto.isEmpty
                ? const Icon(Icons.person, size: 72, color: Colors.white54)
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.peerName,
            style:
                AppTypography.displayMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _getCallStatusText(),
            style:
                AppTypography.bodyLarge.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 54,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.44),
      ),
    );
  }
}
