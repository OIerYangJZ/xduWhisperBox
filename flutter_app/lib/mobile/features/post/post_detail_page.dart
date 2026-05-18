import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

import '../widgets/avatar_widget.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/utils/time_utils.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/comment_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'package:xdu_treehole_web/widgets/post_content_body.dart';
import 'image_gallery.dart';
import 'comment_input_bar.dart';

/// 甯栧瓙璇︽儏椤?
/// 鍖呭惈甯栧瓙姝ｆ枃銆佸浘鐗囩敾寤娿€佽瘎璁哄垪琛ㄣ€佺偣璧?鏀惰棌/涓炬姤浜や簰
class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  final String? initialCommentId;

  const PostDetailPage({
    super.key,
    required this.postId,
    this.initialCommentId,
  });

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage>
    with WidgetsBindingObserver {
  PostItem? _post;
  bool _postIsLiked = false;
  List<CommentItem> _comments = [];
  CommentSort _commentSort = CommentSort.hot;
  bool _isLoading = true;
  String? _error;
  bool _isLiking = false;
  bool _isFavoriting = false;
  bool _isPostingComment = false;
  bool _isSortingComments = false;
  bool _isFollowing = false;
  bool _isDeletingComment = false;
  bool _showEmoji = false;
  bool _pendingShowEmojiPanel = false;

  // 鍥炲鐘舵€?
  CommentItem? _replyingTo;

  // 鐢ㄤ簬閿洏寮硅捣鏃惰嚜鍔ㄦ粴鍔ㄥ埌搴曢儴
  final ScrollController _scrollController = ScrollController();

  // 鐢ㄤ簬婊氬姩鍒拌瘎璁哄尯
  final GlobalKey _commentsSectionKey = GlobalKey();

  // 鐢ㄤ簬鎿嶄綔璇勮杈撳叆妗?
  final GlobalKey<dynamic> _commentInputKey = GlobalKey();
  final Map<String, GlobalKey> _commentItemKeys = <String, GlobalKey>{};
  String _initialCommentId = '';
  bool _didHandleInitialCommentScroll = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialCommentId = (widget.initialCommentId ?? '').trim();
    _ensureCurrentUserLoaded();
    _loadData(recordView: true);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_pendingShowEmojiPanel) {
      return;
    }
    if (_keyboardInset > 0) {
      return;
    }
    _pendingShowEmojiPanel = false;
    if (_showEmoji) {
      return;
    }
    setState(() {
      _showEmoji = true;
    });
  }

  String get _currentUserId => AuthStore.instance.currentUser?.userId ?? '';

  double get _keyboardInset {
    final FlutterView? view = View.maybeOf(context);
    if (view != null) {
      return view.viewInsets.bottom / view.devicePixelRatio;
    }
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 0;
    }
    final FlutterView fallbackView = views.first;
    return fallbackView.viewInsets.bottom / fallbackView.devicePixelRatio;
  }

  Future<void> _ensureCurrentUserLoaded() async {
    if (_currentUserId.isNotEmpty) {
      return;
    }
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadData({bool recordView = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (recordView) {
        await postRepo.incrementView(widget.postId);
      }
      final post = await postRepo.fetchPostDetail(widget.postId);
      final comments = await postRepo.fetchComments(
        widget.postId,
        sort: _commentSort,
      );

      if (mounted) {
        setState(() {
          _post = post;
          _postIsLiked = post.isLiked;
          _commentItemKeys.clear();
          _comments = _buildCommentTree(comments);
          _isLoading = false;
        });
        _scrollToInitialCommentIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 灏嗘墎骞崇殑璇勮鍒楄〃杞崲涓哄祵濂楁爲缁撴瀯
  List<CommentItem> _buildCommentTree(List<CommentItem> flat) {
    final Map<String, CommentItem> map = {};
    for (final c in flat) {
      map[c.id] = CommentItem(
        id: c.id,
        authorAlias: c.authorAlias,
        content: c.content,
        createdAt: c.createdAt,
        likeCount: c.likeCount,
        authorAvatar: c.authorAvatar,
        isLiked: c.isLiked,
        isPinned: c.isPinned,
        parentId: c.parentId,
        authorUserId: c.authorUserId,
        replyCount: c.replyCount,
        replies: [],
      );
    }
    final List<CommentItem> roots = [];
    for (final c in flat) {
      final node = map[c.id]!;
      if (c.parentId.isEmpty || !map.containsKey(c.parentId)) {
        roots.add(node);
      } else {
        map[c.parentId]!.replies.add(node);
      }
    }
    return _sortCommentTree(roots, _commentSort);
  }

  List<CommentItem> _sortCommentTree(
    List<CommentItem> comments,
    CommentSort sort,
  ) {
    final List<CommentItem> sorted = comments.map((CommentItem comment) {
      if (comment.replies.isEmpty) {
        return comment;
      }
      return comment.copyWith(replies: _sortCommentTree(comment.replies, sort));
    }).toList();

    sorted.sort(
      (CommentItem a, CommentItem b) => _compareCommentsForDisplay(a, b, sort),
    );
    return sorted;
  }

  int _compareCommentsForDisplay(
    CommentItem a,
    CommentItem b,
    CommentSort sort,
  ) {
    switch (sort) {
      case CommentSort.hot:
        final int byHot = _commentHotScore(b).compareTo(_commentHotScore(a));
        if (byHot != 0) {
          return byHot;
        }
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        final int byReplies = b.effectiveReplyCount.compareTo(
          a.effectiveReplyCount,
        );
        if (byReplies != 0) {
          return byReplies;
        }
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      case CommentSort.latest:
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
    }
  }

  int _commentHotScore(CommentItem comment) {
    return (comment.likeCount * 3) + (comment.effectiveReplyCount * 2);
  }

  Future<void> _handleLike() async {
    if (_isLiking || _post == null) return;

    final wasLiked = _postIsLiked;
    final previousPost = _post!;
    setState(() {
      _isLiking = true;
      _post = _post!.copyWith(
        likeCount: wasLiked ? _post!.likeCount - 1 : _post!.likeCount + 1,
      );
      _postIsLiked = !wasLiked;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasLiked) {
        await postRepo.unlikePost(widget.postId);
      } else {
        await postRepo.likePost(widget.postId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _post = previousPost;
          _postIsLiked = wasLiked;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _handleFavorite() async {
    if (_isFavoriting || _post == null) return;

    // 涔愯鏇存柊
    final previousPost = _post!;
    final wasFavorited = _post!.isFavorited;
    setState(() {
      _isFavoriting = true;
      _post = _post!.copyWith(
        isFavorited: !wasFavorited,
        favoriteCount: wasFavorited
            ? _post!.favoriteCount - 1
            : _post!.favoriteCount + 1,
      );
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasFavorited) {
        await postRepo.unfavoritePost(widget.postId);
      } else {
        await postRepo.favoritePost(widget.postId);
      }
    } catch (e) {
      // 鍥炴粴
      if (mounted) {
        setState(() {
          _post = previousPost;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriting = false;
        });
      }
    }
  }

  Future<void> _handleReport() async {
    final colors = MobileColors.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ReportSheet(
        postId: widget.postId,
        postRepo: ref.read(postRepositoryProvider),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('举报成功，我们会尽快处理')));
    }
  }

  Future<void> _handleSubmitComment(String content) async {
    if (_isPostingComment) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.createComment(
        postId: widget.postId,
        content: content,
        parentId: _replyingTo?.id,
      );

      // 閲嶆柊鍔犺浇璇勮
      final comments = await postRepo.fetchComments(
        widget.postId,
        sort: _commentSort,
      );

      // 涔愯鏇存柊甯栧瓙璇勮鏁?
      if (mounted && _post != null) {
        setState(() {
          _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
          _comments = _buildCommentTree(comments);
          _replyingTo = null; // 娓呯┖鍥炲鐘舵€?
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评论成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评论失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  void _handleDm() async {
    if (_post == null || !_post!.canMessageAuthor) return;
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final conversation = await messageRepo.createDirectConversation(
        _post!.authorUserId,
        fromPostId: _post!.id,
      );
      if (!mounted) return;
      context.push(
        '/chat/${conversation.id}?name=${Uri.encodeComponent(conversation.name)}&avatar=${Uri.encodeComponent(conversation.avatarUrl)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法发起私信: $e')));
    }
  }

  Future<void> _handleFollowAuthor() async {
    final post = _post;
    if (post == null ||
        _isFollowing ||
        post.isFollowingAuthor ||
        !post.canFollowAuthor ||
        post.authorUserId.isEmpty) {
      return;
    }

    setState(() {
      _isFollowing = true;
    });
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.followUser(post.authorUserId);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = post.copyWith(isFollowingAuthor: true);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关注成功')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowing = false;
        });
      }
    }
  }

  Future<void> _handleDeleteComment(CommentItem comment) async {
    if (_isDeletingComment) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('删除评论'),
            content: const Text('确认删除这条评论吗？删除后不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  '删除',
                  style: TextStyle(color: MobileTheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    setState(() {
      _isDeletingComment = true;
    });
    try {
      await ref.read(userRepositoryProvider).deleteMyComment(comment.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论已删除')));
      await _loadData(recordView: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingComment = false;
        });
      }
    }
  }

  void _scrollToComments() {
    final keyContext = _commentsSectionKey.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  GlobalKey _commentKeyFor(String commentId) {
    return _commentItemKeys.putIfAbsent(commentId, () => GlobalKey());
  }

  void _scrollToInitialCommentIfNeeded() {
    if (_didHandleInitialCommentScroll || _initialCommentId.isEmpty) {
      return;
    }
    _didHandleInitialCommentScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final GlobalKey? key = _commentItemKeys[_initialCommentId];
      final BuildContext? targetContext = key?.currentContext;
      if (targetContext == null) {
        _scrollToComments();
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }

  void _toggleEmoji() {
    final bool keyboardVisible = _keyboardInset > 0;
    if (_showEmoji) {
      _pendingShowEmojiPanel = false;
      setState(() {
        _showEmoji = false;
      });
      return;
    }
    if (keyboardVisible) {
      _pendingShowEmojiPanel = true;
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _pendingShowEmojiPanel = false;
    setState(() {
      _showEmoji = true;
    });
  }

  void _handleCommentInputFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _pendingShowEmojiPanel = false;
      if (_showEmoji) {
        setState(() {
          _showEmoji = false;
        });
      }
      return;
    }
  }

  void _handleCommentInputTap() {
    _pendingShowEmojiPanel = false;
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
    }
  }

  void _onEmojiTap(String emoji) {
    // 閫氳繃 GlobalKey 鎵惧埌 CommentInputBar 鍐呴儴鐘舵€侊紝璋冪敤 insertEmoji
    final inputState = _commentInputKey.currentState;
    if (inputState != null) {
      // dynamic call 鈥?insertEmoji 鏄?_CommentInputBarState 鐨勫叕寮€鏂规硶
      // ignore: avoid_dynamic_calls
      inputState.insertEmoji(emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('帖子详情'),
        actions: [
          if (_post != null)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showOptionsSheet(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : _post == null
          ? _buildEmptyView()
          : _buildContent(),
      bottomNavigationBar: _post != null && _post!.allowComment
          ? Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.divider, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null) _buildReplyBanner(),
                    _buildBottomBarWithEmoji(),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBottomBarWithEmoji() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommentInputBar(
            key: _commentInputKey,
            onSubmit: _handleSubmitComment,
            autofocus: false,
            scrollController: _scrollController,
            onEmojiToggle: _toggleEmoji,
            onFocusChanged: _handleCommentInputFocusChanged,
            onTextFieldTap: _handleCommentInputTap,
          ),
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: _showEmoji ? 200 : 0,
              child: _showEmoji
                  ? EmojiPickerBar(onEmojiTap: _onEmojiTap)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MobileTheme.primaryWithAlpha(context, 0.08),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: MobileTheme.primaryOf(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '回复 @${_replyingTo!.authorAlias}',
              style: TextStyle(
                fontSize: 13,
                color: MobileTheme.primaryOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: MobileTheme.primaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Text('帖子不存在或已被删除', style: TextStyle(color: colors.textSecondary)),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: MobileTheme.primaryOf(context),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 甯栧瓙鍐呭
                  _buildPostContent(),

                  // 鎿嶄綔鏍忥細鐐硅禐/鏀惰棌/璇勮/鍒嗕韩
                  _buildActionBar(),

                  const Divider(height: 1),

                  // 璇勮鍖?
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent() {
    final colors = MobileColors.of(context);
    final post = _post!;
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(post);

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 浣滆€呬俊鎭?
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // 澶村儚
                GestureDetector(
                  onTap: () {
                    // 鍖垮悕甯栨垨鑷繁鐨勫笘瀛愪笉璺宠浆锛堣嚜宸辩殑甯栧瓙鏃犳硶浠庡叏灞忛〉 push Shell 鍒嗘敮璺敱锛?
                    if (!post.isAnonymous &&
                        post.authorUserId.isNotEmpty &&
                        !post.isOwnPost) {
                      context.push('/user/${post.authorUserId}');
                    }
                  },
                  child: AvatarWidget(
                    avatarUrl: post.isAnonymous ? null : post.authorAvatarUrl,
                    nickname: post.isAnonymous ? '匿' : post.authorAlias,
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorAlias,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            _formatTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary,
                            ),
                          ),
                          if (post.status == PostStatus.resolved) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: MobileTheme.success.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                '已解决',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MobileTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if ((post.canMessageAuthor && post.authorUserId.isNotEmpty) ||
                    (post.canFollowAuthor &&
                        post.authorUserId.isNotEmpty &&
                        !post.isFollowingAuthor))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (post.canMessageAuthor && post.authorUserId.isNotEmpty)
                        TextButton.icon(
                          onPressed: _handleDm,
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('私信'),
                          style: TextButton.styleFrom(
                            foregroundColor: MobileTheme.primaryOf(context),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      if (post.canFollowAuthor &&
                          post.authorUserId.isNotEmpty &&
                          !post.isFollowingAuthor)
                        TextButton.icon(
                          onPressed: _isFollowing ? null : _handleFollowAuthor,
                          icon: const Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 16,
                          ),
                          label: const Text('关注'),
                          style: TextButton.styleFrom(
                            foregroundColor: MobileTheme.primaryOf(context),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // 鏍囬
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 4),
              child: SelectableText(
                post.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),

          // 姝ｆ枃
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12, color: colors.textPrimary),
              child: PostContentBody(
                content: post.content,
                contentFormat: post.contentFormat,
                markdownSource: post.markdownSource,
                selectable: true,
              ),
            ),
          ),

          // 鍥剧墖
          if (post.hasImage && supplementaryImageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PostImageGrid(imageUrls: supplementaryImageUrls),
            ),

          // 鏍囩
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.tags.map((tag) {
                  return Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 13,
                      color: MobileTheme.primaryOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _supplementaryImageUrls(PostItem post) {
    if (!post.isMarkdown || post.markdownSource.trim().isEmpty) {
      return post.imageUrls;
    }
    return post.imageUrls
        .where((String url) => !post.markdownSource.contains(url))
        .toList();
  }

  Future<void> _changeCommentSort(CommentSort nextSort) async {
    if (_isSortingComments || _commentSort == nextSort) {
      return;
    }
    final previousSort = _commentSort;
    setState(() {
      _commentSort = nextSort;
      _isSortingComments = true;
    });
    try {
      final comments = await ref
          .read(postRepositoryProvider)
          .fetchComments(widget.postId, sort: nextSort);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _buildCommentTree(comments);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commentSort = previousSort;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切换排序失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSortingComments = false;
        });
      }
    }
  }

  Future<void> _showCommentSortMenu(TapDownDetails details) async {
    if (_isSortingComments) {
      return;
    }
    _pendingShowEmojiPanel = false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
    }
    final colors = MobileColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final double left = (details.globalPosition.dx - 44).clamp(
      12,
      size.width - 140,
    );
    final double top = details.globalPosition.dy + 8;
    final RelativeRect position = RelativeRect.fromLTRB(
      left,
      top,
      size.width - (left + 128),
      0,
    );
    final CommentSort? selected = await showMenu<CommentSort>(
      context: context,
      position: position,
      color: colors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: <PopupMenuEntry<CommentSort>>[
        PopupMenuItem<CommentSort>(
          value: CommentSort.hot,
          child: _buildSortMenuItem(
            label: '热度',
            selected: _commentSort == CommentSort.hot,
          ),
        ),
        PopupMenuItem<CommentSort>(
          value: CommentSort.latest,
          child: _buildSortMenuItem(
            label: '时间',
            selected: _commentSort == CommentSort.latest,
          ),
        ),
      ],
    );
    if (selected != null) {
      await _changeCommentSort(selected);
    }
  }

  Widget _buildSortMenuItem({required String label, required bool selected}) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: MobileTheme.primaryOf(context),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String get _commentSortLabel => _commentSort == CommentSort.hot ? '热度' : '时间';

  Widget _buildCommentsSection() {
    final colors = MobileColors.of(context);
    return Container(
      key: _commentsSectionKey,
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 璇勮鍖烘爣棰?
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _showCommentSortMenu,
                  child: Row(
                    children: [
                      Text(
                        _commentSortLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isSortingComments)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // 璇勮鍒楄〃
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '暂无评论，快来抢沙发~',
                  style: TextStyle(color: colors.textTertiary, fontSize: 14),
                ),
              ),
            )
          else
            _buildCommentList(_comments),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final post = _post!;
    final colors = MobileColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          // 鐐硅禐
          _ActionItem(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: post.likeCount > 0 ? '${post.likeCount}' : '',
            isActive: _postIsLiked,
            isLoading: _isLiking,
            activeColor: const Color(0xFFFF2D55),
            onTap: _handleLike,
          ),
          const SizedBox(width: 22),

          // 鏀惰棌
          _ActionItem(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            label: post.favoriteCount > 0 ? '${post.favoriteCount}' : '',
            isActive: post.isFavorited,
            isLoading: _isFavoriting,
            activeColor: const Color(0xFFFF9500),
            onTap: _handleFavorite,
            iconSize: 22,
          ),
          const SizedBox(width: 22),

          // 璇勮
          _ActionItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: post.commentCount > 0 ? '${post.commentCount}' : '',
            isActive: false,
            activeColor: MobileTheme.primaryOf(context),
            onTap: () {
              _scrollToComments();
            },
          ),

          const Spacer(),

          // 鍒嗕韩
          IconButton(
            icon: Icon(Icons.share_outlined, color: colors.textPrimary),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '查看西电树洞帖子: ${widget.postId}'),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('链接已复制到剪贴板')));
            },
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: MobileTheme.error,
              ),
              title: const Text('举报'),
              onTap: () {
                Navigator.pop(context);
                _handleReport();
              },
            ),
            if (_post!.isOwnPost)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: MobileTheme.error,
                ),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除这篇帖子吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final postRepo = ref.read(postRepositoryProvider);
                await postRepo.deleteMyPost(widget.postId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('删除成功')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 閫掑綊娓叉煋宓屽璇勮鍒楄〃
  Widget _buildCommentList(
    List<CommentItem> comments, {
    bool isNested = false,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (_, __) => isNested
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 60),
      itemBuilder: (context, index) {
        final comment = comments[index];
        final bool needsTopSpacing = !isNested && index > 0;
        return Padding(
          padding: EdgeInsets.only(top: needsTopSpacing ? 10 : 0),
          child: _CommentTile(
            comment: comment,
            indentLevel: isNested ? 1 : 0,
            onReply: (c) => setState(() => _replyingTo = c),
            commentKeyBuilder: _commentKeyFor,
            currentUserId: _currentUserId,
            onDelete: _handleDeleteComment,
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 璇勮鍒楄〃椤?
class _CommentTile extends StatefulWidget {
  final CommentItem comment;
  final void Function(CommentItem)? onReply;
  final int indentLevel;
  final GlobalKey Function(String commentId)? commentKeyBuilder;
  final String currentUserId;
  final Future<void> Function(CommentItem comment)? onDelete;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.indentLevel = 0,
    this.commentKeyBuilder,
    this.currentUserId = '',
    this.onDelete,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
  }

  @override
  void didUpdateWidget(_CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.likeCount;
    }
  }

  Future<void> _toggleLike(BuildContext context) async {
    final wasLiked = _isLiked;
    // 涔愯鏇存柊
    setState(() {
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      final repo = ProviderScope.containerOf(
        context,
      ).read(postRepositoryProvider);
      if (wasLiked) {
        await repo.unlikeComment(widget.comment.id);
      } else {
        await repo.likeComment(widget.comment.id);
      }
    } catch (_) {
      // 鍥炴粴
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  bool get _canDelete {
    final String userId = widget.currentUserId.trim();
    return userId.isNotEmpty && userId == widget.comment.authorUserId;
  }

  Future<void> _showActionMenu(LongPressStartDetails details) async {
    HapticFeedback.mediumImpact();
    final media = MediaQuery.of(context);
    final _CommentAction? action = await showMenu<_CommentAction>(
      context: context,
      color: MobileColors.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy - 10,
        media.size.width - details.globalPosition.dx,
        media.size.height - details.globalPosition.dy,
      ),
      items: <PopupMenuEntry<_CommentAction>>[
        const PopupMenuItem<_CommentAction>(
          value: _CommentAction.copy,
          child: Text('复制'),
        ),
        if (_canDelete && widget.onDelete != null)
          const PopupMenuItem<_CommentAction>(
            value: _CommentAction.delete,
            child: Text('删除', style: TextStyle(color: MobileTheme.error)),
          ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _CommentAction.copy) {
      await Clipboard.setData(ClipboardData(text: widget.comment.content));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制评论内容')));
      return;
    }
    if (action == _CommentAction.delete && _canDelete) {
      await widget.onDelete?.call(widget.comment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final colors = MobileColors.of(context);
    // 澶村儚灏哄锛氭瘡缂╄繘涓€灞傜缉灏?dp锛屾渶澶氱缉鍒?4dp锛堝熀纭€浠?2寮€濮嬶級
    final double avatarRadius = (22 - widget.indentLevel * 2)
        .clamp(14, 22)
        .toDouble();
    // 宸︿晶缂╄繘锛氭瘡灞?0dp锛屾渶澶х缉杩?0dp
    final double leftPadding = (widget.indentLevel * 20)
        .clamp(0, 60)
        .toDouble();
    // 瑙嗚缂╄繘鏈€澶氬睍绀哄埌 3 灞傦紝閬垮厤杩囨繁宓屽鎶婃鏂囨尋娌★紱
    // 浣嗚瘎璁哄唴瀹规湰韬户缁€掑綊娓叉煋锛屼笉鎴柇妤间腑妤笺€?
    final int effectiveIndent = widget.indentLevel.clamp(0, 3);
    final double guideWidth = effectiveIndent * 12.0;

    return Container(
      key: widget.commentKeyBuilder?.call(comment.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: _showActionMenu,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 宸︿晶缂╄繘 + 绔栫嚎
                  SizedBox(
                    width:
                        leftPadding + (effectiveIndent > 0 ? guideWidth : 16),
                    child: effectiveIndent > 0
                        ? Row(
                            children: [
                              SizedBox(width: leftPadding),
                              ...List.generate(effectiveIndent, (i) {
                                return Container(
                                  width: 2,
                                  margin: const EdgeInsets.only(right: 10),
                                  color: colors.divider,
                                );
                              }),
                            ],
                          )
                        : SizedBox(width: leftPadding),
                  ),
                  // 澶村儚
                  Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: comment.authorUserId.isNotEmpty
                          ? () => context.push('/user/${comment.authorUserId}')
                          : null,
                      child: AvatarWidget(
                        avatarUrl: comment.authorAvatar,
                        nickname: comment.authorAlias,
                        radius: avatarRadius,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 鍐呭
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 鏄电О + 鏃堕棿
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: comment.authorUserId.isNotEmpty
                                    ? () => context.push(
                                        '/user/${comment.authorUserId}',
                                      )
                                    : null,
                                child: Text(
                                  comment.authorAlias,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: comment.authorUserId.isNotEmpty
                                        ? MobileTheme.primaryOf(context)
                                        : colors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(comment.createdAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // 姝ｆ枃锛氱偣鍑昏Е鍙戝洖澶?
                        GestureDetector(
                          onTap: () => widget.onReply?.call(comment),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            comment.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 搴曢儴鎿嶄綔鏍忥細鐐硅禐 + 鍥炲鏁?
                        Row(
                          children: [
                            // 鐐硅禐
                            GestureDetector(
                              onTap: () => _toggleLike(context),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: _isLiked
                                        ? MobileTheme.accent
                                        : colors.textPrimary,
                                  ),
                                  if (_likeCount > 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_likeCount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _isLiked
                                            ? MobileTheme.accent
                                            : colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // 鍥炲鏁?
                            GestureDetector(
                              onTap: () => widget.onReply?.call(comment),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                    color: colors.textPrimary,
                                  ),
                                  if (comment.effectiveReplyCount > 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${comment.effectiveReplyCount}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 閫掑綊娓叉煋瀛愬洖澶嶏紱瓒呰繃 3 灞傚悗涓嶅啀澧炲姞瑙嗚缂╄繘锛屼絾缁х画鏄剧ず鍐呭
          if (comment.replies.isNotEmpty)
            ...comment.replies.map(
              (reply) => _CommentTile(
                comment: reply,
                indentLevel: widget.indentLevel + 1,
                onReply: widget.onReply,
                commentKeyBuilder: widget.commentKeyBuilder,
                currentUserId: widget.currentUserId,
                onDelete: widget.onDelete,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

/// 搴曢儴鎿嶄綔鎸夐挳
enum _CommentAction { copy, delete }

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final Color activeColor;
  final VoidCallback onTap;
  final double iconSize;

  const _ActionItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.isLoading = false,
    required this.activeColor,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final inactiveColor = colors.textPrimary;
    final Color effectiveColor = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Row(
        children: [
          isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: inactiveColor,
                  ),
                )
              : Icon(
                  isActive ? activeIcon : icon,
                  size: iconSize,
                  color: effectiveColor,
                ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: effectiveColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 涓炬姤琛ㄥ崟
class _ReportSheet extends StatefulWidget {
  final String postId;
  final PostRepository postRepo;

  const _ReportSheet({required this.postId, required this.postRepo});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = ['垃圾广告', '人身攻击', '色情低俗', '违法违规', '虚假信息', '侵犯隐私', '其他'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择举报原因')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final postRepo = widget.postRepo;
      await postRepo.report(
        targetType: 'post',
        targetId: widget.postId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, _selectedReason);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('举报失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '举报原因',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final isSelected = reason == _selectedReason;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MobileTheme.error.withValues(alpha: 0.1)
                        : colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? MobileTheme.error : colors.divider,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? MobileTheme.error
                          : colors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '补充说明（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: MobileTheme.error,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('提交举报'),
            ),
          ),
        ],
      ),
    );
  }
}
