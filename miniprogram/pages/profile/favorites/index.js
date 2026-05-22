import { getFavoritePosts, unfavoritePost } from '../../../api/posts';
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
    if (!requireLoginPage()) return;
    this.setData({ loading: true });
    try {
      const posts = await getFavoritePosts();
      this.setData({ posts, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  async removeFavorite(event) {
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post) return;
    try {
      await unfavoritePost(post.id);
      const posts = this.data.posts.slice();
      posts.splice(index, 1);
      this.setData({ posts });
      wx.showToast({ title: '已取消收藏', icon: 'success' });
    } catch (error) {}
  }
});
