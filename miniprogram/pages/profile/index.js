import { getUserInfo } from '../../api/auth';
import { fetchDmRequests, getConversations } from '../../api/messages';
import { getNotifications } from '../../api/notifications';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

Page({
  data: {
    isLoggedIn: false,
    userInfo: null,
    unreadCount: 0,
    messageUnreadCount: 0,
    messageRequestPending: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    setTimeout(() => {
      applyThemeAndLanguage(this);
      this.checkLoginStatus();
    }, 0);
  },

  checkLoginStatus() {
    const token = wx.getStorageSync('token');
    if (token) {
      this.setData({ isLoggedIn: true });
      this.fetchUserInfo();
    } else {
      this.setData({
        isLoggedIn: false,
        userInfo: null,
        unreadCount: 0,
        messageUnreadCount: 0,
        messageRequestPending: false
      });
      wx.navigateTo({ url: '/pages/profile/auth/index' });
    }
  },

  async fetchUserInfo() {
    // 并发请求，互不阻塞
    getUserInfo().then(res => {
      if (res && res.data) {
        this.setData({ userInfo: res.data });
      }
    }).catch(err => {
      console.error('获取用户信息失败', err);
    });
    getNotifications().then(notifications => {
      this.setData({ unreadCount: (notifications && notifications.unreadCount) || 0 });
    }).catch(() => {});
    this.fetchMessageBadge();
  },

  async fetchMessageBadge() {
    try {
      const [conversations, requests] = await Promise.all([
        getConversations(),
        fetchDmRequests()
      ]);
      const messageUnreadCount = conversations.reduce(
        (sum, item) => sum + (Number(item.unreadCount) || 0),
        0
      );
      const messageRequestPending = requests.some(item => item.status === 'pending');
      this.setData({
        messageUnreadCount,
        messageRequestPending
      });
    } catch (error) {
      this.setData({
        messageUnreadCount: 0,
        messageRequestPending: false
      });
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
    wx.switchTab({ url: '/pages/profile/conversations/index' });
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

