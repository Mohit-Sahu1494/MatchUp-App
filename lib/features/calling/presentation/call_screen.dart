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

  const CallScreen({
    super.key,
    required this.webrtcService,
    required this.peerName,
    required this.peerPhoto,
    this.isVideo = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallState _callState = CallState.outgoing;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    widget.webrtcService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() => _callState = state);
        if (state == CallState.connected) {
          _startDurationTimer();
        } else if (state == CallState.ended) {
          _durationTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    };
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video or Audio Avatar Placeholder
            if (widget.isVideo && _callState == CallState.connected)
              RTCVideoView(
                widget.webrtcService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _buildAudioAvatarView(),

            // Local Video Preview (Picture in Picture)
            if (widget.isVideo && !widget.webrtcService.isVideoOff)
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
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Top Header: Peer Name, Status & Duration
            Positioned(
              top: AppSpacing.xl,
              left: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: AppTypography.displayMedium.copyWith(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _callState == CallState.connected ? AppColors.likeGreen : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getCallStatusText(),
                        style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Call Control Toolbar
            Positioned(
              bottom: AppSpacing.xxl,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute
                  _buildCircleButton(
                    icon: widget.webrtcService.isMuted ? Icons.mic_off : Icons.mic,
                    color: widget.webrtcService.isMuted ? Colors.white : Colors.white24,
                    iconColor: widget.webrtcService.isMuted ? Colors.black : Colors.white,
                    onTap: () {
                      setState(() => widget.webrtcService.toggleMute());
                    },
                  ),

                  // Speaker Toggle
                  _buildCircleButton(
                    icon: widget.webrtcService.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: widget.webrtcService.isSpeakerOn ? Colors.white : Colors.white24,
                    iconColor: widget.webrtcService.isSpeakerOn ? Colors.black : Colors.white,
                    onTap: () {
                      setState(() => widget.webrtcService.toggleSpeaker());
                    },
                  ),

                  // Camera Toggle (for video calls)
                  if (widget.isVideo) ...[
                    _buildCircleButton(
                      icon: widget.webrtcService.isVideoOff ? Icons.videocam_off : Icons.videocam,
                      color: widget.webrtcService.isVideoOff ? Colors.white : Colors.white24,
                      iconColor: widget.webrtcService.isVideoOff ? Colors.black : Colors.white,
                      onTap: () {
                        setState(() => widget.webrtcService.toggleVideo());
                      },
                    ),
                    _buildCircleButton(
                      icon: Icons.switch_camera,
                      color: Colors.white24,
                      iconColor: Colors.white,
                      onTap: () => widget.webrtcService.switchCamera(),
                    ),
                  ],

                  // End / Hangup Button
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
            radius: 64,
            backgroundImage: widget.peerPhoto.isNotEmpty ? NetworkImage(widget.peerPhoto) : null,
            child: widget.peerPhoto.isEmpty ? const Icon(Icons.person, size: 64) : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.peerName,
            style: AppTypography.displayMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _getCallStatusText(),
            style: AppTypography.bodyLarge.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  String _getCallStatusText() {
    switch (_callState) {
      case CallState.outgoing:
        return 'Calling student...';
      case CallState.incoming:
        return 'Incoming call...';
      case CallState.connected:
        return 'Connected • ${_formatDuration(_callDurationSeconds)}';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
