import 'package:flutter/material.dart';

/// PNG frame sequence animator
/// 
/// Usage:
///   PngAnimation(
///     frames: List.generate(8, (i) => 'assets/images/searching_${i+1}.png'),
///     frameRate: 12,  // frames per second
///     size: 200,
///   )
class PngAnimation extends StatefulWidget {
  final List<String> frames;
  final int frameRate;
  final double size;
  final BoxFit fit;
  final bool loop;
  
  const PngAnimation({
    super.key,
    required this.frames,
    this.frameRate = 12,
    this.size = 200,
    this.fit = BoxFit.contain,
    this.loop = true,
  });
  
  @override
  State<PngAnimation> createState() => _PngAnimationState();
}

class _PngAnimationState extends State<PngAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    final durationMs = (1000 * widget.frames.length / widget.frameRate).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    
    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final frameIndex = (_controller.value * widget.frames.length)
            .floor()
            .clamp(0, widget.frames.length - 1);
        
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.asset(
            widget.frames[frameIndex],
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: widget.size,
                height: widget.size,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 40),
              );
            },
          ),
        );
      },
    );
  }
}