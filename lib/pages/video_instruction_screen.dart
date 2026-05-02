import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoInstructionScreen extends StatefulWidget {
  const VideoInstructionScreen({super.key});

  @override
  State<VideoInstructionScreen> createState() => _VideoInstructionScreenState();
}

class _VideoInstructionScreenState extends State<VideoInstructionScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // Asset dosyasını libmpv ile (yazılımsal/donanımsal karışık en güvenli oynatıcı) açıyoruz
      await player.open(Media('asset://assets/video/Instruction.mp4'));
      await player.setVolume(100.0);
      await player.setPlaylistMode(PlaylistMode.none);

      // Video bittiğinde yakalamak için
      player.stream.completed.listen((completed) {
        if (completed) {
          _navigateToHome();
        }
      });

      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
          });
        }
      });

    } catch (e) {
      debugPrint('MediaKit başlatılamadı: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _navigateToHome() async {
    // Sadece bir kere çalışmasını sağlamak için
    if (player.state.playing) {
      await player.pause();
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87, // Yarı saydam arkaplan
      body: Stack(
        children: [
          // Video Player
          Center(
            child: _hasError
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        const Text(
                          "Video oynatılamadı.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : AspectRatio(
                    aspectRatio: 1.0, // Kare video, asıl boyutu media_kit kendi ayarlar
                    child: Video(
                      controller: controller,
                      controls: NoVideoControls, // Alt barda gereksiz butonları kaldırıyoruz
                      fill: Colors.transparent,
                    ),
                  ),
          ),
          
          // "Atla" (Skip) Butonu
          Positioned(
            top: 50,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _navigateToHome,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Atla',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
