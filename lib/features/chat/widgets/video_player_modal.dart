import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';

class VideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerModal({
    super.key,
    required this.videoUrl,
    this.title = 'Video',
  });

  static Future<void> show(BuildContext context, {required String videoUrl, String title = 'Video'}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => VideoPlayerModal(videoUrl: videoUrl, title: title),
    );
  }

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      _controller.setLooping(true);
      await _controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black54,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Player Content
              AspectRatio(
                aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInitialized)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                        },
                        child: VideoPlayer(_controller),
                      )
                    else if (_hasError)
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 40),
                          SizedBox(height: 8),
                          Text('Unable to play video', style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    else
                      const Center(child: CircularProgressIndicator(color: AppColors.primary)),

                    // Play/Pause Overlay
                    if (_isInitialized && !_controller.value.isPlaying)
                      GestureDetector(
                        onTap: () => setState(() => _controller.play()),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                        ),
                      ),
                  ],
                ),
              ),

              // Progress Bar if initialized
              if (_isInitialized)
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.black26,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
