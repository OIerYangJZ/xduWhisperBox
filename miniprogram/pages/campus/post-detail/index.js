import {
  createComment,
  deleteComment,
  deletePost,
  favoritePost,
  getPost,
  getPostComments,
  incrementPostView,
  reportTarget,
  toggleCommentLike,
  togglePostLike,
  unfavoritePost
} from '../../../api/posts';
import { createDirectConversation } from '../../../api/messages';
import { followUser, unfollowUser } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { markdownToNodes } from '../../../utils/markdown';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const REPORT_REASONS = ['广告引流', '人身攻击', '违规内容', '垃圾信息', '其他'];
const COMMENT_SORTS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' }
];
const EMOJIS = [
  '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
  '🙂', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘',
  '😋', '😛', '😜', '🤪', '😝', '🤗', '🤭', '🤫',
  '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒',
  '🙄', '😬', '😮‍💨', '🤥', '😌', '😔', '😪', '🤤',
  '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵',
  '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓',
  '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺',
  '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱',
  '👍', '👎', '👏', '🙌', '🤝', '🙏', '💪', '🤘'
];
const COMMENT_SORT_LABELS = {
  latest: '时间',
  hot: '热度'
};

const buildCommentRows = (comments, targetCommentId = '') => {
  const byParent = {};
  comments.forEach((item) => {
    const parentId = item.parentId || '';
    if (!byParent[parentId]) byParent[parentId] = [];
    byParent[parentId].push(item);
  });
  const rows = [];
  const visit = (parentId, level) => {
    (byParent[parentId] || []).forEach((item) => {
      rows.push({
        ...item,
        anchorId: `comment-${item.id}`,
        isTarget: item.id === targetCommentId,
        indentLevel: Math.min(level, 2),
        indentStyle: `margin-left: ${Math.min(level, 2) * 44}rpx`
      });
      visit(item.id, level + 1);
    });
  };
  visit('', 0);
  return rows;
};

Page({
  data: {
    postId: '',
    navTop: 0,
    navHeight: 0,
    post: null,
    contentNodes: [],
    comments: [],
    commentSorts: COMMENT_SORTS,
    commentSort: 'latest',
    commentSortLabel: COMMENT_SORT_LABELS.latest,
    targetCommentId: '',
    targetAnchor: '',
    emojis: EMOJIS,
    showEmojiPanel: false,
    loading: true,
    commentContent: '',
    canSendComment: false,
    replyToId: '',
    replyToName: '',
    isSending: false,
    isLiking: false,
    isFavoriting: false,
    isFollowing: false
  },

  onLoad(options) {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    if (options.id) this.setData({ postId: options.id });
    if (options.commentId) {
      this.setData({
        targetCommentId: options.commentId,
        targetAnchor: `comment-${options.commentId}`
      });
    }
    if (!requireLoginPage()) return;
    if (this.data.postId) {
      this.loadDetail();
      incrementPostView(this.data.postId).catch(() => {});
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  onPullDownRefresh() {
    this.loadDetail().finally(() => wx.stopPullDownRefresh());
  },

  onShareAppMessage() {
    const title = this.data.post ? this.data.post.displayTitle : '西电树洞';
    return {
      title,
      path: `/pages/campus/post-detail/index?id=${this.data.postId}`
    };
  },

  initCustomNav() {
    const menuButton = wx.getMenuButtonBoundingClientRect();
    this.setData({
      navTop: menuButton.top,
      navHeight: menuButton.height
    });
  },

  goBack() {
    wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/campus/index' }) });
  },

  async loadDetail() {
    this.setData({ loading: true });
    try {
      const [post, comments] = await Promise.all([
        getPost(this.data.postId),
        getPostComments(this.data.postId, { page: 1, limit: 100, sort: this.data.commentSort })
      ]);
      this.setData({
        post,
        contentNodes: markdownToNodes(post.contentFormat === 'markdown' ? (post.markdownSource || post.content) : post.content),
        comments: buildCommentRows(comments, this.data.targetCommentId),
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async handleLike() {
    if (!this.data.post || this.data.isLiking) return;
    this.setData({ isLiking: true });
    try {
      const result = await togglePostLike(this.data.postId);
      const liked = Boolean(result.liked);
      const post = this.data.post;
      this.setData({
        post: {
          ...post,
          liked,
          isLiked: liked,
          likeCount: Math.max(0, post.likeCount + (liked ? 1 : -1))
        }
      });
    } catch (error) {
    } finally {
      this.setData({ isLiking: false });
    }
  },

  async handleFavorite() {
    if (!this.data.post || this.data.isFavoriting) return;
    this.setData({ isFavoriting: true });
    const post = this.data.post;
    try {
      const result = post.favorited ? await unfavoritePost(post.id) : await favoritePost(post.id);
      this.setData({
        post: {
          ...post,
          favorited: Boolean(result.favorited),
          isFavorited: Boolean(result.favorited),
          favoriteCount: Number(result.favoriteCount || post.favoriteCount)
        }
      });
    } catch (error) {
    } finally {
      this.setData({ isFavoriting: false });
    }
  },

  reportPost() {
    if (!this.data.post) return;
    this.chooseReportReason('post', this.data.post.id);
  },

  chooseReportReason(targetType, targetId) {
    wx.showActionSheet({
      itemList: REPORT_REASONS,
      success: (res) => {
        const reason = REPORT_REASONS[res.tapIndex];
        if (!reason) return;
        wx.showModal({
          title: `举报：${reason}`,
          editable: true,
          placeholderText: '补充描述（选填）',
          confirmText: '提交',
          success: async (modal) => {
            if (!modal.confirm) return;
            try {
              await reportTarget({ targetType, targetId, reason, description: String(modal.content || '').trim() });
              wx.showToast({ title: '举报已提交', icon: 'success' });
            } catch (error) {}
          }
        });
      }
    });
  },

  deleteOwnPost() {
    if (!this.data.post || !this.data.post.isOwnPost) return;
    wx.showModal({
      title: '删除帖子',
      content: '确认删除这条帖子？',
      confirmText: '删除',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await deletePost(this.data.postId);
          wx.showToast({ title: '已删除', icon: 'success' });
          setTimeout(() => wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/campus/index' }) }), 500);
        } catch (error) {}
      }
    });
  },

  openAuthorProfile() {
    const userId = this.data.post && this.data.post.authorUserId;
    if (this.data.post && this.data.post.isOwnPost) {
      wx.switchTab({ url: '/pages/profile/index' });
      return;
    }
    if (!userId || this.data.post.isAnonymous) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  openCommentAuthor(event) {
    const userId = event.currentTarget.dataset.id;
    if (userId) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  async messageAuthor() {
    if (!this.data.post || !this.data.post.authorUserId || this.data.post.isAnonymous || !this.data.post.canMessageAuthor) return;
    try {
      const conversation = await createDirectConversation({
        targetUserId: this.data.post.authorUserId,
        postId: this.data.post.id
      });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}&peerUserId=${encodeURIComponent(this.data.post.authorUserId)}&peerAvatar=${encodeURIComponent((this.data.post && this.data.post.authorAvatarUrl) || conversation.avatarUrl || '')}`
      });
    } catch (error) {}
  },

  async toggleFollowAuthor() {
    const post = this.data.post;
    const userId = post && post.authorUserId;
    if (!userId || this.data.isFollowing) return;
    this.setData({ isFollowing: true });
    try {
      if (post.followingAuthor || post.isFollowingAuthor || post.isFollowing) {
        await unfollowUser(userId);
        this.setData({ post: { ...post, followingAuthor: false, isFollowingAuthor: false, isFollowing: false } });
      } else {
        await followUser(userId);
        this.setData({ post: { ...post, followingAuthor: true, isFollowingAuthor: true, isFollowing: true } });
        wx.showToast({ title: '关注成功', icon: 'success' });
      }
    } catch (error) {
    } finally {
      this.setData({ isFollowing: false });
    }
  },

  previewPostImage(event) {
    const current = event.currentTarget.dataset.url;
    const urls = (this.data.post && this.data.post.imageUrls) || [];
    if (current && urls.length) wx.previewImage({ current, urls });
  },

  onCommentSortTap(event) {
    const sort = event.currentTarget.dataset.sort;
    if (!sort || sort === this.data.commentSort) return;
    this.setData({ commentSort: sort, commentSortLabel: COMMENT_SORT_LABELS[sort] || '时间' });
    this.loadDetail();
  },

  showCommentSortMenu() {
    wx.showActionSheet({
      itemList: ['热度', '时间'],
      success: (res) => {
        const sort = res.tapIndex === 0 ? 'hot' : 'latest';
        if (sort === this.data.commentSort) return;
        this.setData({
          commentSort: sort,
          commentSortLabel: COMMENT_SORT_LABELS[sort]
        });
        this.loadDetail();
      }
    });
  },

  scrollToComments() {
    this.setData({ targetAnchor: '' }, () => {
      wx.nextTick(() => {
        if (this.data.targetAnchor !== 'comments-section') {
          this.setData({ targetAnchor: 'comments-section' });
        }
      });
    });
  },

  showPostOptions() {
    if (!this.data.post) return;
    const itemList = ['举报'];
    if (this.data.post.isOwnPost) itemList.push('删除');
    wx.showActionSheet({
      itemList,
      success: (res) => {
        const action = itemList[res.tapIndex];
        if (action === '举报') this.reportPost();
        if (action === '删除') this.deleteOwnPost();
      }
    });
  },

  onCommentInput(event) {
    const value = event.detail.value;
    this.setData({
      commentContent: value,
      canSendComment: value.trim().length > 0 && !this.data.isSending
    });
  },

  toggleEmojiPanel() {
    this.setData({ showEmojiPanel: !this.data.showEmojiPanel });
  },

  insertEmoji(event) {
    const emoji = event.currentTarget.dataset.emoji || '';
    const next = `${this.data.commentContent}${emoji}`;
    this.setData({
      commentContent: next,
      canSendComment: next.trim().length > 0 && !this.data.isSending
    });
  },

  setReplyTarget(event) {
    const item = this.data.comments[Number(event.currentTarget.dataset.index)];
    if (!item) return;
      this.setData({
        replyToId: item.id,
        replyToName: item.authorAlias || item.authorName || '同学'
      });
  },

  clearReplyTarget() {
    this.setData({ replyToId: '', replyToName: '' });
  },

  async submitComment() {
    const content = this.data.commentContent.trim();
    if (!content || this.data.isSending) {
      if (!content) wx.showToast({ title: '评论内容不能为空', icon: 'none' });
      return;
    }
    this.setData({ isSending: true });
    try {
      await createComment(this.data.postId, {
        content,
        isAnonymous: false,
        parentId: this.data.replyToId
      });
      this.setData({
        commentContent: '',
        canSendComment: false,
        replyToId: '',
        replyToName: '',
        showEmojiPanel: false
      });
      await this.loadDetail();
      wx.showToast({ title: '评论成功', icon: 'success' });
    } catch (error) {}
    this.setData({
      isSending: false,
      canSendComment: this.data.commentContent.trim().length > 0
    });
  },

  async likeComment(event) {
    const index = Number(event.currentTarget.dataset.index);
    const comment = this.data.comments[index];
    if (!comment) return;
    try {
      const result = await toggleCommentLike(comment.id);
      const liked = Boolean(result.liked);
      const comments = this.data.comments.slice();
      comments[index] = {
        ...comment,
        liked,
        isLiked: liked,
        likeCount: Math.max(0, comment.likeCount + (liked ? 1 : -1))
      };
      this.setData({ comments });
    } catch (error) {}
  },

  reportComment(event) {
    const comment = this.data.comments[Number(event.currentTarget.dataset.index)];
    if (comment) this.chooseReportReason('comment', comment.id);
  },

  copyComment(event) {
    const comment = this.data.comments[Number(event.currentTarget.dataset.index)];
    if (!comment) return;
    wx.setClipboardData({ data: comment.content || '' });
  },

  showCommentMenu(event) {
    const index = Number(event.currentTarget.dataset.index);
    const comment = this.data.comments[index];
    if (!comment) return;
    const itemList = ['复制'];
    if (comment.isOwnComment) itemList.push('删除');
    wx.showActionSheet({
      itemList,
      success: (res) => {
        const action = itemList[res.tapIndex];
        if (action === '复制') this.copyComment({ currentTarget: { dataset: { index } } });
        if (action === '删除') this.deleteOwnComment({ currentTarget: { dataset: { index } } });
      }
    });
  },

  deleteOwnComment(event) {
    const index = Number(event.currentTarget.dataset.index);
    const comment = this.data.comments[index];
    if (!comment) return;
    wx.showModal({
      title: '删除评论',
      content: '确认删除这条评论？',
      confirmText: '删除',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await deleteComment(comment.id);
          await this.loadDetail();
          wx.showToast({ title: '已删除', icon: 'success' });
        } catch (error) {}
      }
    });
  }
});
