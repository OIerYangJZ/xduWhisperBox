import { getUserInfo } from '../../api/auth';
import { getNotifications } from '../../api/notifications';
import { requireLoginPage } from '../../utils/auth_guard';

Page({
  data: {
    isLoggedIn: false,
    userInfo: null,
    unreadCount: 0
  },

  onShow() {
    if (!requireLoginPage()) {
      this.setData({ isLoggedIn: false, userInfo: null, unreadCount: 0 });
      return;
    }
    this.checkLoginStatus();
  },

  checkLoginStatus() {
    const token = wx.getStorageSync('token');
    if (token) {
      this.setData({ isLoggedIn: true });
      this.fetchUserInfo();
    } else {
      this.setData({ isLoggedIn: false, userInfo: null });
      requireLoginPage();
    }
  },

  async fetchUserInfo() {
    try {
      const res = await getUserInfo();
      if (res.data) {
        this.setData({ userInfo: res.data });
      }
      const notifications = await getNotifications();
      this.setData({ unreadCount: notifications.unreadCount });
    } catch (err) {
      console.error('获取用户信息失败', err);
    }
  },

  goToLogin() {
    wx.navigateTo({ url: '/pages/profile/auth/index' });
  },

  goToFavorites() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/favorites/index' });
  },

  goToMyPosts() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/my-posts/index' });
  },

  goToMyComments() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/my-comments/index' });
  },

  goToMyReports() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/my-reports/index' });
  },

  goToConversations() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/conversations/index' });
  },

  goToSocialList(event) {
    if (!this.data.isLoggedIn) return this.goToLogin();
    const type = event.currentTarget.dataset.type || 'friends';
    wx.navigateTo({ url: `/pages/profile/social-list/index?type=${type}` });
  },

  goToNotifications() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/notifications/index' });
  },

  goToFeedback() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/feedback/index' });
  },

  goToSettings() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/settings/index' });
  },

  goToLegal(event) {
    const type = event.currentTarget.dataset.type || 'about';
    wx.navigateTo({ url: `/pages/profile/legal/index?type=${type}` });
  }
});
