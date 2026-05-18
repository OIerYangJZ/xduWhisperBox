import { getPostById, likePost } from '../../../api/post';
import { getComments, createComment } from '../../../api/comment';

Page({
  data: {
    postId: '',
    post: null,
    comments: [],
    loading: true,
    commentContent: '',
    isSending: false
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ postId: options.id });
      this.fetchPostDetail();
      this.fetchComments();
    }
  },

  async fetchPostDetail() {
    try {
      const res = await getPostById(this.data.postId);
      if (res && res.data) {
        this.setData({ post: res.data, loading: false });
      }
    } catch (err) {
      this.setData({ loading: false });
      wx.showToast({ title: '加载帖子失败', icon: 'none' });
    }
  },

  async fetchComments() {
    try {
      const res = await getComments(this.data.postId, { page: 1, limit: 50 });
      if (res && res.data) {
        this.setData({ comments: res.data.items || [] });
      }
    } catch (err) {
      console.error('获取评论失败', err);
    }
  },

  async handleLike() {
    if (!this.data.post) return;
    const isLike = !this.data.post.isLiked;
    
    // 乐观更新
    const originalPost = { ...this.data.post };
    this.setData({
      'post.isLiked': isLike,
      'post.likeCount': isLike ? originalPost.likeCount + 1 : originalPost.likeCount - 1
    });

    try {
      await likePost(this.data.postId, isLike);
    } catch (err) {
      // 回滚
      this.setData({ post: originalPost });
    }
  },

  onCommentInput(e) {
    this.setData({ commentContent: e.detail.value });
  },

  async submitComment() {
    const content = this.data.commentContent.trim();
    if (!content) {
      wx.showToast({ title: '评论内容不能为空', icon: 'none' });
      return;
    }

    this.setData({ isSending: true });
    wx.showLoading({ title: '发送中...' });

    try {
      await createComment(this.data.postId, {
        content,
        isAnonymous: false // 默认实名，如果需要可以增加匿名切换开关
      });
      wx.hideLoading();
      wx.showToast({ title: '评论成功', icon: 'success' });
      this.setData({ commentContent: '', isSending: false });
      this.fetchComments(); // 刷新评论
    } catch (err) {
      wx.hideLoading();
      this.setData({ isSending: false });
    }
  }
});
