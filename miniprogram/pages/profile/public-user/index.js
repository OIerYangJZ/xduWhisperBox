import { followUser, getPublicUser, unfollowUser } from '../../../api/user';
import { getPosts } from '../../../api/posts';
import { createDirectConversation } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    userId: '',
    profile: null,
    posts: [],
    loading: true
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const userId = options.id || '';
    this.setData({ userId });
    if (userId) this.loadProfile();
  },

  async loadProfile() {
    this.setData({ loading: true });
    try {
      const [profile, posts] = await Promise.all([
        getPublicUser(this.data.userId),
        getPosts({ authorId: this.data.userId, page: 1, limit: 20 })
      ]);
      wx.setNavigationBarTitle({ title: profile.nickname || profile.alias || '主页' });
      this.setData({ profile, posts, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async toggleFollow() {
    if (!this.data.profile) return;
    try {
      if (this.data.profile.isFollowing) {
        await unfollowUser(this.data.userId);
      } else {
        await followUser(this.data.userId);
      }
      this.setData({ 'profile.isFollowing': !this.data.profile.isFollowing });
    } catch (error) {}
  },

  async messageUser() {
    if (!this.data.profile || !this.data.profile.canDirectMessage) return;
    try {
      const conversation = await createDirectConversation({ targetUserId: this.data.userId });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}&peerUserId=${encodeURIComponent(this.data.userId)}&peerAvatar=${encodeURIComponent((this.data.profile && this.data.profile.avatarUrl) || conversation.avatarUrl || '')}`
      });
    } catch (error) {}
  },

  openPost(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
