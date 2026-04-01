import 'package:flutter/material.dart';

/// 骨架屏骨架块
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 首页频道骨架屏（频道 Chip 行 + 排序栏 + 3 个帖子卡片占位）
class HomePageShimmer extends StatefulWidget {
  const HomePageShimmer({super.key});

  @override
  State<HomePageShimmer> createState() => _HomePageShimmerState();
}

class _HomePageShimmerState extends State<HomePageShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          color: const Color(0xFFF5F5F7),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // 频道 Chip 行骨架
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 7,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ShimmerChip(animation: _animation),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 排序栏骨架
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ShimmerChip(
                        animation: _animation,
                        width: 120,
                        height: 32,
                      ),
                      _ShimmerChip(
                        animation: _animation,
                        width: 72,
                        height: 32,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 帖子卡片骨架
                for (int i = 0; i < 3; i++) ...[
                  _ShimmerPostCard(animation: _animation),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerChip extends StatelessWidget {
  final Animation<double> animation;
  final double width;
  final double height;

  const _ShimmerChip({
    required this.animation,
    this.width = 64,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFE8E8ED),
            Color(0xFFF5F5F7),
            Color(0xFFE8E8ED),
          ],
          stops: [
            (animation.value - 0.3).clamp(0.0, 1.0),
            animation.value.clamp(0.0, 1.0),
            (animation.value + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPostCard extends StatelessWidget {
  final Animation<double> animation;

  const _ShimmerPostCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerLine(animation: animation, width: 56, height: 20),
              _ShimmerLine(animation: animation, width: 48, height: 16),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerLine(animation: animation, width: double.infinity, height: 18),
          const SizedBox(height: 8),
          _ShimmerLine(animation: animation, width: 200, height: 16),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShimmerLine(animation: animation, width: 60, height: 14),
              const SizedBox(width: 16),
              _ShimmerLine(animation: animation, width: 48, height: 14),
              const SizedBox(width: 16),
              _ShimmerLine(animation: animation, width: 40, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final Animation<double> animation;
  final double width;
  final double height;

  const _ShimmerLine({
    required this.animation,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFE8E8ED),
            Color(0xFFF5F5F7),
            Color(0xFFE8E8ED),
          ],
          stops: [
            (animation.value - 0.3).clamp(0.0, 1.0),
            animation.value.clamp(0.0, 1.0),
            (animation.value + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}
