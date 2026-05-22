import { getMyComments } from '../../../api/user';
import { deleteComment } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    comments: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const comments = await getMyComments();
      this.setData({ comments, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openPost(event) {
    const postId = event.currentTarget.dataset.postId;
    const commentId = event.currentTarget.dataset.commentId;
    if (postId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}` });
    }
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
          const comments = this.data.comments.slice();
          comments.splice(index, 1);
          this.setData({ comments });
          wx.showToast({ title: '已删除', icon: 'success' });
        } catch (error) {}
      }
    });
  }
});
