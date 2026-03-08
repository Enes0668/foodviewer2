import 'package:flutter/material.dart';

class CustomLoadingAnimation extends StatefulWidget {
  final Color? color;
  final double size;

  const CustomLoadingAnimation({super.key, this.color, this.size = 50.0});

  @override
  State<CustomLoadingAnimation> createState() => _CustomLoadingAnimationState();
}

class _CustomLoadingAnimationState extends State<CustomLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).primaryColor;

    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                // Her bir nokta için gecikmeli (staggered) bir dalga efekti oluştur
                final delay = index * 0.2;
                final animationValue = (_controller.value - delay) % 1.0;
                final offsetValue = animationValue < 0
                    ? animationValue + 1.0
                    : animationValue;

                // Yukarı ve aşağı hareketi hesapla (sinüs dalgası)
                double yOffset = 0.0;
                if (offsetValue < 0.5) {
                  // İlk yarıda yukarı ve aşağı (0 -> 1 -> 0)
                  yOffset = -8.0 * (0.5 - (0.5 - offsetValue).abs()) * 2;
                }

                // Opaklık hesapla
                double opacity = 0.4;
                if (offsetValue < 0.5) {
                  opacity = 0.4 + (0.6 * (1.0 - (0.5 - offsetValue).abs() * 2));
                }

                return Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Container(
                    width: widget.size * 0.2,
                    height: widget.size * 0.2,
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(opacity.clamp(0.0, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
