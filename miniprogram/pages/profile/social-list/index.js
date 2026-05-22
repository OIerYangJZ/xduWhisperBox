import { getFollowers, getFollowing, getFriends } from '../../../api/user';
import { createDirectConversation } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const TITLE_MAP = {
  following: '关注',
  followers: '粉丝',
  friends: '好友'
};

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    type: 'friends',
    loading: true,
    users: []
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const type = options.type || 'friends';
    wx.setNavigationBarTitle({ title: TITLE_MAP[type] || '关系' });
    this.setData({ type });
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const users = this.data.type === 'following'
        ? await getFollowing()
        : this.data.type === 'followers'
          ? await getFollowers()
          : await getFriends();
      this.setData({ users, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openUser(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  },

  async messageUser(event) {
    const id = event.currentTarget.dataset.id;
    const avatarUrl = event.currentTarget.dataset.avatar || '';
    if (!id) return;
    try {
      const conversation = await createDirectConversation({ targetUserId: id });
      wx.navigateTo({
        url: `/pages/profile/chat/index?id=${conversation.id}&name=${encodeURIComponent(conversation.name || '私信')}&peerUserId=${encodeURIComponent(id)}&peerAvatar=${encodeURIComponent(avatarUrl || conversation.avatarUrl || '')}`
      });
    } catch (error) {}
  }
});
