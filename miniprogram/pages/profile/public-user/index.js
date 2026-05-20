import { followUser, getPublicUser, unfollowUser } from '../../../api/user';
import { createDirectConversation } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    userId: '',
    profile: null,
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
      const profile = await getPublicUser(this.data.userId);
      wx.setNavigationBarTitle({ title: profile.nickname || profile.alias || '主页' });
      this.setData({ profile, loading: false });
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
    try {
      const conversation = await createDirectConversation({ targetUserId: this.data.userId });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}`
      });
    } catch (error) {}
  }
});
