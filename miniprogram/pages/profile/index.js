import { getUserInfo } from '../../api/auth';

Page({
  data: {
    isLoggedIn: false,
    userInfo: null
  },

  onShow() {
    this.checkLoginStatus();
  },

  checkLoginStatus() {
    const token = wx.getStorageSync('token');
    if (token) {
      this.setData({ isLoggedIn: true });
      this.fetchUserInfo();
    } else {
      this.setData({ isLoggedIn: false, userInfo: null });
    }
  },

  async fetchUserInfo() {
    try {
      const res = await getUserInfo();
      if (res.data) {
        this.setData({ userInfo: res.data });
      }
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

  goToFeedback() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/feedback/index' });
  },

  goToSettings() {
    if (!this.data.isLoggedIn) return this.goToLogin();
    wx.navigateTo({ url: '/pages/profile/settings/index' });
  }
});
