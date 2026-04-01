import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';
import 'package:xdu_treehole_web/models/public_user_profile.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import '../home/post_card.dart';

class PublicUserProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const PublicUserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<PublicUserProfilePage> createState() =>
      _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends ConsumerState<PublicUserProfilePage> {
  PublicUserProfile? _profile;
  List<PostItem> _posts = [];
  bool _loadingProfile = true;
  bool _loadingPosts = true;
  bool _isFollowing = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userRepo = ref.read(userRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);

    try {
      final profile = await userRepo.fetchUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isFollowing = profile.isFollowing;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }

    try {
      final posts = await postRepo.fetchUserPosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _posts = posts.where((p) => p.authorUserId == widget.userId).toList();
        _loadingPosts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
    }
  }

  Future<void> _handleFollow() async {
    if (_followLoading || _profile == null) return;
    setState(() => _followLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      if (_isFollowing) {
        await userRepo.unfollowUser(widget.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = false;
          _profile = _profile!.copyWith(
            isFollowing: false,
            followerCount: _profile!.followerCount - 1,
          );
        });
      } else {
        await userRepo.followUser(widget.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
          _profile = _profile!.copyWith(
            isFollowing: true,
            followerCount: _profile!.followerCount + 1,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    }
    if (mounted) setState(() => _followLoading = false);
  }

  Future<void> _handleDm() async {
    if (_profile == null) return;
    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final conversation = await messageRepo.createDirectConversation(
        widget.userId,
      );
      if (!mounted) return;
      context.push(
        '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.name)}&avatar=${Uri.encodeComponent(conversation.avatarUrl)}&userId=${Uri.encodeComponent(conversation.peerUserId)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法发起私信: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: MobileTheme.primaryOf(context),
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text('用户不存在', style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              backgroundColor: colors.surface,
              scrolledUnderElevation: 0.5,
              toolbarHeight: 48,
              title: Text(
                profile.nickname,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 60,
                      color: MobileTheme.primaryWithAlpha(context, 0.08),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -24),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 4,
                                ),
                              ),
                              child: AvatarWidget(
                                avatarUrl: profile.avatarUrl,
                                nickname: profile.nickname,
                                radius: 36,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Transform.translate(
                            offset: const Offset(0, -16),
                            child: Row(
                              children: [
                                if (profile.canFollow)
                                  _FollowButton(
                                    isFollowing: _isFollowing,
                                    loading: _followLoading,
                                    onTap: _handleFollow,
                                  ),
                                if (profile.canDirectMessage) ...[
                                  const SizedBox(width: 8),
                                  _DmButton(onTap: _handleDm),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        profile.nickname,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          _StatChip(label: '帖子', value: '${profile.postCount}'),
                          const SizedBox(width: 20),
                          _StatChip(
                            label: '粉丝',
                            value: '${profile.followerCount}',
                          ),
                          const SizedBox(width: 20),
                          _StatChip(
                            label: '关注',
                            value: '${profile.followingCount}',
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MobileTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profile.userLevelLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MobileTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 0.5, color: colors.divider),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _loadingPosts
            ? Center(
                child: CircularProgressIndicator(
                  color: MobileTheme.primaryOf(context),
                ),
              )
            : _posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无帖子',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 0),
                itemCount: _posts.length,
                itemBuilder: (context, i) {
                  final post = _posts[i];
                  return PostCard(
                    post: post,
                    onTap: () => context.push('/post/${post.id}'),
                    onLike: () async {
                      try {
                        final repo = ref.read(postRepositoryProvider);
                        if (post.isLiked) {
                          await repo.unlikePost(post.id);
                        } else {
                          await repo.likePost(post.id);
                        }
                        _load();
                      } catch (_) {}
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Row(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool loading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    if (loading) {
      return Container(
        width: 80,
        height: 32,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MobileTheme.primaryOf(context),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? colors.surface : MobileTheme.primaryOf(context),
          border: Border.all(
            color: isFollowing
                ? colors.divider
                : MobileTheme.primaryOf(context),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? '已关注' : '关注',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFollowing ? colors.textPrimary : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DmButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DmButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 14, color: colors.textPrimary),
            const SizedBox(width: 4),
            Text(
              '私信',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
