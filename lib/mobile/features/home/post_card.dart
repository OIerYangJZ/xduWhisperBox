import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/utils/time_utils.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import '../post/image_gallery.dart';
import '../widgets/avatar_widget.dart';

/// Instagram 风格帖子卡片
/// 无边距、无圆角、无阴影、全宽紧贴屏幕
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final bool showTopDivider;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.showTopDivider = true,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _busy = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  bool _showDots = false;
  Timer? _dotsHideTimer;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _currentImageIndex = 0;
      _showDots = false;
      _dotsHideTimer?.cancel();
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _dotsHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenImage(int initialIndex) {
    ImageGallery.show(
      context,
      imageUrls: widget.post.imageUrls,
      initialIndex: initialIndex,
    );
  }

  Future<void> _handleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      widget.onLike?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTopDivider)
          Container(height: 0.5, color: colors.divider),
        GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列：头像
                _buildAvatar(),
                const SizedBox(width: 10),
                // 右列：内容
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
        Container(height: 0.5, color: colors.divider),
      ],
    );
  }

  Widget _buildAvatar() {
    final bool isAnon = widget.post.isAnonymous;
    final bool hasUserId = widget.post.authorUserId.isNotEmpty;
    return GestureDetector(
      onTap: () {
        // 匿名帖一律不能通过头像查看主页
        if (!isAnon && hasUserId) {
          if (widget.post.isOwnPost) {
            context.push('/profile');
          } else {
            context.push('/user/${widget.post.authorUserId}');
          }
        }
      },
      child: AvatarWidget(
        avatarUrl: isAnon ? null : widget.post.authorAvatarUrl,
        nickname: isAnon ? '匿' : widget.post.authorAlias,
        radius: 20,
      ),
    );
  }

  Widget _buildContent() {
    if (widget.post.hasImage && widget.post.imageUrls.isNotEmpty) {
      return _buildImagePostContent();
    }

    return _buildTextPostContent();
  }

  /// 图文帖：标题 + PageView 图片（无正文）
  Widget _buildImagePostContent() {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        const SizedBox(height: 4),

        // 标题 - 18sp Bold
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        // 图片 PageView - 固定高度 280dp
        _buildImagePageView(),

        // 标签
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTags(),
        ],

        const SizedBox(height: 8),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildImagePageView() {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.post.imageUrls.length,
              onPageChanged: (index) {
                _dotsHideTimer?.cancel();
                setState(() {
                  _currentImageIndex = index;
                  _showDots = true;
                });
                _dotsHideTimer = Timer(const Duration(seconds: 1), () {
                  if (mounted) setState(() => _showDots = false);
                });
              },
              itemBuilder: (context, index) {
                final fullUrl = _resolveImageUrl(widget.post.imageUrls[index]);
                return GestureDetector(
                  onTap: () => _openFullScreenImage(index),
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: colors.divider,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.divider,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.textTertiary,
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
            // 圆点指示器 - 仅滑动时显示，停止1秒后自动隐藏
            if (widget.post.imageUrls.length > 1 && _showDots)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.post.imageUrls.length, (i) {
                    final isActive = _currentImageIndex == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 8 : 6,
                      height: isActive ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 纯文帖：标题 + 正文（最多4行）
  Widget _buildTextPostContent() {
    final colors = MobileColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        const SizedBox(height: 4),

        // 标题 - 18sp Bold
        if (widget.post.title.isNotEmpty) ...[
          Text(
            widget.post.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],

        // 正文 - 最多 4 行
        Text(
          widget.post.content,
          style: TextStyle(
            fontSize: 14,
            color: colors.textPrimary,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),

        // 标签
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildTags(),
        ],

        const SizedBox(height: 8),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildHeaderRow() {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Row(
      children: [
        Text(
          widget.post.authorAlias,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        _ChannelDot(channel: widget.post.channel),
        if (widget.post.isPinned) ...[
          const SizedBox(width: 6),
          Icon(Icons.push_pin, size: 14, color: primaryColor),
        ],
        const Spacer(),
        Text(
          _formatTime(widget.post.createdAt),
          style: TextStyle(fontSize: 14, color: colors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildTags() {
    final primaryColor = MobileTheme.primaryOf(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: widget.post.tags.take(3).map((tag) {
        return Text(
          '#$tag',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBar() {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            count: _likeCount,
            isActive: _isLiked,
            activeColor: const Color(0xFFFF2D55),
            onTap: _busy ? null : _handleLike,
          ),
          const SizedBox(width: 24),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            count: widget.post.commentCount,
            isActive: false,
            activeColor: primaryColor,
            onTap: widget.onTap,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _handleShare(context),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.share_outlined,
                size: 22,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleShare(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)),
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }

  String _resolveImageUrl(String imageUrl) {
    return imageUrl.startsWith('http')
        ? imageUrl
        : AppConfig.resolveUrl(imageUrl);
  }
}

/// 频道彩色圆点 + 频道名文本
class _ChannelDot extends StatelessWidget {
  final String channel;

  const _ChannelDot({required this.channel});

  static const _channelColors = {
    '全部': Color(0xFF8E8E93),
    '综合': Color(0xFF6B7FD7),
    '学习': Color(0xFF5E8FD4),
    '二手': Color(0xFF5EAF7C),
    '找搭子': Color(0xFFE09C5E),
    '失物': Color(0xFFD45E8A),
    '吐槽': Color(0xFF9B6ED4),
    '租房': Color(0xFF5EC4AF),
    '问答': Color(0xFF5EAAD4),
  };

  @override
  Widget build(BuildContext context) {
    final displayChannel = channel == '其他' ? '综合' : channel;
    final color =
        _channelColors[displayChannel] ?? MobileTheme.primaryOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          displayChannel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final inactiveColor = colors.textPrimary;
    final effectiveColor = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 22, color: effectiveColor),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
