import { getMyPosts } from '../../../api/user';
import { deletePost, updatePost } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    posts: []
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
      const posts = await getMyPosts();
      this.setData({ posts, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  async changeStatus(event) {
    const index = Number(event.currentTarget.dataset.index);
    const status = event.currentTarget.dataset.status;
    const post = this.data.posts[index];
    if (!post || !status) return;
    try {
      const updated = await updatePost(post.id, { status });
      const posts = this.data.posts.slice();
      posts[index] = updated;
      this.setData({ posts });
      wx.showToast({ title: '已更新', icon: 'success' });
    } catch (error) {}
  },

  deleteOwnPost(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post) return;
    wx.showModal({
      title: '删除发布',
      content: '删除后无法在前台展示，确认删除？',
      confirmText: '删除',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await deletePost(post.id);
          const posts = this.data.posts.slice();
          posts.splice(index, 1);
          this.setData({ posts });
          wx.showToast({ title: '已删除', icon: 'success' });
        } catch (error) {}
      }
    });
  }
});
