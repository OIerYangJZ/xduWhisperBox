import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../models/comment_item.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';
import '../../widgets/image_gallery.dart';
import '../../widgets/post_content_body.dart';
import '../messages/chat_page.dart';
import '../profile/public_user_profile_page.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});

  final PostItem post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  late PostItem _post;
  List<CommentItem> _comments = const <CommentItem>[];
  String? _replyToCommentId;
  String? _replyToAlias;
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadDetail(recordView: true);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> supplementaryImageUrls = _supplementaryImageUrls(_post);
    return Scaffold(
      appBar: AppBar(title: const Text('帖子详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_post.channel),
                          ),
                          const SizedBox(width: 8),
                          Chip(label: Text(_post.status.label)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _post.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      PostContentBody(
                        content: _post.content,
                        contentFormat: _post.contentFormat,
                        markdownSource: _post.markdownSource,
                        selectable: !_post.isMarkdown,
                      ),
                      if (supplementaryImageUrls.isNotEmpty)
                        ImageGallery(images: supplementaryImageUrls),
                      if (_post.hasImage && supplementaryImageUrls.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '图片暂时不可用，请稍后重试',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: _post.tags
                            .map((String tag) => Chip(label: Text('#$tag')))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_post.isAnonymous ? '匿名身份' : '作者'}：${_post.authorAlias}',
                      ),
                      Text('发布时间：${_post.createdAt.toLocal()}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (_post.canViewAuthorProfile &&
                              _post.authorUserId.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _openAuthorProfile,
                              icon: const Icon(Icons.person_outline),
                              label: const Text('查看主页'),
                            ),
                          if (_post.canFollowAuthor &&
                              _post.authorUserId.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _actionBusy
                                  ? null
                                  : _toggleFollowAuthor,
                              icon: Icon(
                                _post.isFollowingAuthor
                                    ? Icons.person_remove_alt_1_outlined
                                    : Icons.person_add_alt_1_outlined,
                              ),
                              label: Text(
                                _post.isFollowingAuthor ? '取消关注' : '关注作者',
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _like,
                            icon: const Icon(Icons.thumb_up_alt_outlined),
                            label: Text('点赞 ${_post.likeCount}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _toggleFavorite,
                            icon: Icon(
                              _post.isFavorited
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            label: Text(
                              '${_post.isFavorited ? '取消收藏' : '收藏'} ${_post.favoriteCount}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy ? null : _report,
                            icon: const Icon(Icons.report_gmailerrorred),
                            label: const Text('举报'),
                          ),
                          if (!_post.isMarkdown)
                            OutlinedButton.icon(
                              onPressed: _copyPostContent,
                              icon: const Icon(Icons.copy_all_rounded),
                              label: const Text('复制内容'),
                            ),
                          if (_post.canMessageAuthor)
                            OutlinedButton.icon(
                              onPressed: _actionBusy ? null : _requestDm,
                              icon: const Icon(Icons.forum_outlined),
                              label: const Text('私信作者'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '评论区（${_countComments(_comments)}）',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (_comments.isEmpty)
                        const Text('暂无评论，来抢沙发。')
                      else
                        ..._comments.asMap().entries.map(
                          (MapEntry<int, CommentItem> entry) =>
                              _CommentThreadTile(
                                comment: entry.value,
                                floorLabel: '${entry.key + 1} 楼',
                                onReply: _actionBusy
                                    ? null
                                    : (CommentItem comment) =>
                                          _prepareReply(comment: comment),
                                onReport: _actionBusy
                                    ? null
                                    : (String commentId) =>
                                          _reportComment(commentId),
                                onOpenAuthor: _openCommentAuthor,
                              ),
                        ),
                      const SizedBox(height: 8),
                      if (_replyToCommentId != null && _replyToAlias != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '正在回复 $_replyToAlias',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                onPressed: _actionBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _replyToCommentId = null;
                                          _replyToAlias = null;
                                        });
                                      },
                                icon: const Icon(Icons.close, size: 16),
                                visualDensity: VisualDensity.compact,
                                tooltip: '取消回复',
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: _replyToCommentId == null
                              ? '发表评论（支持楼中楼回复）'
                              : '输入回复内容',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          EmojiAssistantBar(
                            controller: _commentController,
                            compact: true,
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _actionBusy ? null : _submitComment,
                            child: Text(_actionBusy ? '提交中...' : '发送评论'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadDetail({bool recordView = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (recordView) {
        final int? nextViewCount = await AppRepositories.posts.incrementView(
          widget.post.id,
        );
        if (mounted && nextViewCount != null) {
          setState(() {
            _post = _post.copyWith(viewCount: nextViewCount);
          });
        }
      }
      final PostItem detail = await AppRepositories.posts.fetchPostDetail(
        widget.post.id,
      );
      final List<CommentItem> comments = await AppRepositories.posts
          .fetchComments(widget.post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = detail;
        _comments = _buildCommentTree(comments);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<CommentItem> _buildCommentTree(List<CommentItem> flatComments) {
    final Map<String, CommentItem> commentMap = <String, CommentItem>{};
    for (final CommentItem comment in flatComments) {
      commentMap[comment.id] = comment.copyWith(replies: <CommentItem>[]);
    }
    final List<CommentItem> roots = <CommentItem>[];
    for (final CommentItem comment in flatComments) {
      final CommentItem node = commentMap[comment.id]!;
      if (comment.parentId.isEmpty ||
          !commentMap.containsKey(comment.parentId)) {
        roots.add(node);
      } else {
        commentMap[comment.parentId]!.replies.add(node);
      }
    }
    return roots;
  }

  int _countComments(List<CommentItem> comments) {
    int total = 0;
    for (final CommentItem comment in comments) {
      total += 1 + _countComments(comment.replies);
    }
    return total;
  }

  Future<void> _submitComment() async {
    final String content = _commentController.text.trim();
    if (content.isEmpty) {
      _feedback('评论不能为空');
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      await AppRepositories.posts.createComment(
        postId: _post.id,
        content: content,
        parentId: _replyToCommentId,
      );
      _commentController.clear();
      final List<CommentItem> comments = await AppRepositories.posts
          .fetchComments(_post.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _buildCommentTree(comments);
        _replyToCommentId = null;
        _replyToAlias = null;
      });
      _feedback('评论已发送');
    } catch (error) {
      _feedback('评论失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _like() async {
    await _runAction(
      action: () => AppRepositories.posts.likePost(_post.id),
      success: '已点赞',
    );
  }

  Future<void> _toggleFavorite() async {
    final bool currentFavorited = _post.isFavorited;
    setState(() {
      _actionBusy = true;
    });

    try {
      final FavoriteActionResult result = currentFavorited
          ? await AppRepositories.posts.unfavoritePost(_post.id)
          : await AppRepositories.posts.favoritePost(_post.id);
      if (!mounted) {
        return;
      }

      final int nextCount =
          result.favoriteCount ??
          (result.favorited
              ? (currentFavorited
                    ? _post.favoriteCount
                    : _post.favoriteCount + 1)
              : (currentFavorited
                    ? (_post.favoriteCount > 0 ? _post.favoriteCount - 1 : 0)
                    : _post.favoriteCount));

      setState(() {
        _post = _post.copyWith(
          isFavorited: result.favorited,
          favoriteCount: nextCount,
        );
      });
      _feedback(result.favorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _report() async {
    final Map<String, dynamic>? result = await _showReportDialog();
    if (result == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'post',
        targetId: _post.id,
        reason: result['reason'] as String,
        description: result['description'] as String?,
      ),
      success: '已提交举报',
    );
  }

  Future<void> _reportComment(String commentId) async {
    final Map<String, dynamic>? result = await _showReportDialog();
    if (result == null) return;

    await _runAction(
      action: () => AppRepositories.posts.report(
        targetType: 'comment',
        targetId: commentId,
        reason: result['reason'] as String,
        description: result['description'] as String?,
      ),
      success: '已举报评论',
    );
  }

  Future<Map<String, dynamic>?> _showReportDialog() async {
    String? selectedReason;
    final TextEditingController descController = TextEditingController();

    final List<String> reasons = <String>[
      '垃圾广告',
      '违法违规',
      '色情低俗',
      '人身攻击',
      '虚假信息',
      '侵犯隐私',
      '其他',
    ];

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('举报'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('请选择举报原因：'),
                      const SizedBox(height: 8),
                      ...reasons.map(
                        (String reason) => RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          groupValue: selectedReason,
                          onChanged: (String? value) {
                            setState(() {
                              selectedReason = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLength: 200,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '补充说明（可选）',
                          hintText: '请详细描述举报原因',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: selectedReason == null
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: const Text('确认举报'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || selectedReason == null) {
        return null;
      }

      return <String, dynamic>{
        'reason': selectedReason,
        'description': descController.text.trim(),
      };
    } finally {
      descController.dispose();
    }
  }

  Future<void> _copyPostContent() async {
    if (_post.isMarkdown) {
      _feedback('Markdown 帖子不支持复制内容');
      return;
    }
    final String body = _post.isMarkdown ? _post.markdownSource : _post.content;
    final String text = '[${_post.channel}] ${_post.title}\\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    _feedback('已复制帖子内容');
  }

  List<String> _supplementaryImageUrls(PostItem post) {
    if (!post.isMarkdown || post.markdownSource.trim().isEmpty) {
      return post.imageUrls;
    }
    return post.imageUrls
        .where((String url) => !post.markdownSource.contains(url))
        .toList();
  }

  Future<void> _requestDm() async {
    if (_post.authorUserId.isEmpty || !_post.canMessageAuthor) {
      return;
    }
    try {
      setState(() {
        _actionBusy = true;
      });
      final conversation = await AppRepositories.messages
          .createDirectConversation(_post.authorUserId, fromPostId: _post.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            conversation: conversation,
            peerUserId: _post.authorUserId,
          ),
        ),
      );
    } catch (error) {
      _feedback('无法发起私信：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _toggleFollowAuthor() async {
    if (_post.authorUserId.isEmpty || !_post.canFollowAuthor) {
      return;
    }
    setState(() {
      _actionBusy = true;
    });
    try {
      if (_post.isFollowingAuthor) {
        await AppRepositories.users.unfollowUser(_post.authorUserId);
      } else {
        await AppRepositories.users.followUser(_post.authorUserId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _post = _post.copyWith(isFollowingAuthor: !_post.isFollowingAuthor);
      });
      _feedback(_post.isFollowingAuthor ? '关注成功' : '已取消关注');
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _openAuthorProfile() {
    if (_post.authorUserId.isEmpty) {
      return;
    }
    _openCommentAuthor(_post.authorUserId);
  }

  void _openCommentAuthor(String userId) {
    if (userId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  void _prepareReply({required CommentItem comment}) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToAlias = comment.authorAlias;
    });
    _commentFocusNode.requestFocus();
    _feedback('已选择回复 ${comment.authorAlias}');
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String success,
  }) async {
    setState(() {
      _actionBusy = true;
    });

    try {
      await action();
      _feedback(success);
    } catch (error) {
      _feedback('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  void _feedback(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CommentThreadTile extends StatefulWidget {
  const _CommentThreadTile({
    required this.comment,
    required this.onReply,
    required this.onReport,
    required this.onOpenAuthor,
    this.floorLabel,
    this.depth = 0,
  });

  final CommentItem comment;
  final ValueChanged<CommentItem>? onReply;
  final ValueChanged<String>? onReport;
  final ValueChanged<String> onOpenAuthor;
  final String? floorLabel;
  final int depth;

  @override
  State<_CommentThreadTile> createState() => _CommentThreadTileState();
}

class _CommentThreadTileState extends State<_CommentThreadTile> {
  late bool _isLiked;
  late int _likeCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likeCount = widget.comment.likeCount;
  }

  @override
  void didUpdateWidget(covariant _CommentThreadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id ||
        oldWidget.comment.isLiked != widget.comment.isLiked ||
        oldWidget.comment.likeCount != widget.comment.likeCount) {
      _isLiked = widget.comment.isLiked;
      _likeCount = widget.comment.likeCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) {
      return;
    }
    final bool wasLiked = _isLiked;
    setState(() {
      _busy = true;
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await AppRepositories.posts.unlikeComment(widget.comment.id);
      } else {
        await AppRepositories.posts.likeComment(widget.comment.id);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommentItem comment = widget.comment;
    final double leftInset = (widget.depth * 18).clamp(0, 54).toDouble();
    final String avatarUrl = AppConfig.resolveUrl(
      (comment.authorAvatar ?? '').trim(),
    );
    final String fallback = comment.authorAlias.trim().isEmpty
        ? '匿'
        : comment.authorAlias.trim().characters.first;

    return Padding(
      padding: EdgeInsets.only(left: leftInset, top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.depth == 0 ? Colors.white : const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.depth == 0
                ? const Color(0xFFE9EDF5)
                : const Color(0xFFE2E6EF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GestureDetector(
                  onTap: comment.authorUserId.isEmpty
                      ? null
                      : () => widget.onOpenAuthor(comment.authorUserId),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: avatarUrl.isEmpty
                        ? null
                        : NetworkImage(avatarUrl),
                    child: avatarUrl.isEmpty ? Text(fallback) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: GestureDetector(
                              onTap: comment.authorUserId.isEmpty
                                  ? null
                                  : () => widget.onOpenAuthor(
                                      comment.authorUserId,
                                    ),
                              child: Text(
                                comment.authorAlias,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: comment.authorUserId.isEmpty
                                      ? Colors.black87
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          if (widget.floorLabel != null)
                            Text(
                              widget.floorLabel!,
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.createdAt.toLocal().toString(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              comment.content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: widget.onReply == null
                      ? null
                      : () => widget.onReply!(comment),
                  icon: const Icon(Icons.reply_outlined, size: 16),
                  label: const Text('回复'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _isLiked
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: _busy ? null : _toggleLike,
                  icon: Icon(
                    _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    size: 16,
                  ),
                  label: Text('$_likeCount'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: widget.onReport == null
                      ? null
                      : () => widget.onReport!(comment.id),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('举报'),
                ),
                if (comment.effectiveReplyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: Text(
                      '${comment.effectiveReplyCount} 条回复',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            if (comment.replies.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              ...comment.replies.map(
                (CommentItem reply) => _CommentThreadTile(
                  comment: reply,
                  depth: widget.depth + 1,
                  onReply: widget.onReply,
                  onReport: widget.onReport,
                  onOpenAuthor: widget.onOpenAuthor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
