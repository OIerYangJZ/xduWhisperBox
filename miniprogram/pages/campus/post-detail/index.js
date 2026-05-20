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
import { requireLoginPage } from '../../../utils/auth_guard';

const REPORT_REASONS = ['广告引流', '人身攻击', '违规内容', '垃圾信息', '其他'];

const buildCommentRows = (comments) => {
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
    post: null,
    comments: [],
    loading: true,
    commentContent: '',
    replyToId: '',
    replyToName: '',
    isSending: false
  },

  onLoad(options) {
    if (options.id) this.setData({ postId: options.id });
    if (!requireLoginPage()) return;
    if (this.data.postId) {
      this.loadDetail();
      incrementPostView(this.data.postId).catch(() => {});
    }
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

  async loadDetail() {
    this.setData({ loading: true });
    try {
      const [post, comments] = await Promise.all([
        getPost(this.data.postId),
        getPostComments(this.data.postId, { page: 1, limit: 100 })
      ]);
      this.setData({
        post,
        comments: buildCommentRows(comments),
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async handleLike() {
    if (!this.data.post) return;
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
    } catch (error) {}
  },

  async handleFavorite() {
    if (!this.data.post) return;
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
    } catch (error) {}
  },

  reportPost() {
    if (!this.data.post) return;
    this.chooseReportReason('post', this.data.post.id);
  },

  chooseReportReason(targetType, targetId) {
    wx.showActionSheet({
      itemList: REPORT_REASONS,
      success: async (res) => {
        const reason = REPORT_REASONS[res.tapIndex];
        if (!reason) return;
        try {
          await reportTarget({ targetType, targetId, reason, description: '' });
          wx.showToast({ title: '举报已提交', icon: 'success' });
        } catch (error) {}
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
    if (userId) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  openCommentAuthor(event) {
    const userId = event.currentTarget.dataset.id;
    if (userId) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${userId}` });
  },

  async messageAuthor() {
    if (!this.data.post || !this.data.post.authorUserId) return;
    try {
      const conversation = await createDirectConversation({
        targetUserId: this.data.post.authorUserId,
        postId: this.data.post.id
      });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}`
      });
    } catch (error) {}
  },

  onCommentInput(event) {
    this.setData({ commentContent: event.detail.value });
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
        replyToId: this.data.replyToId
      });
      this.setData({ commentContent: '', replyToId: '', replyToName: '' });
      await this.loadDetail();
      wx.showToast({ title: '评论成功', icon: 'success' });
    } catch (error) {}
    this.setData({ isSending: false });
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
