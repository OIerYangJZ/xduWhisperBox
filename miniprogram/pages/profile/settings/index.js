import { logout } from '../../../api/auth';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    loading: false,
    loggingOut: false
  },

  onShow() {
    requireLoginPage();
  },

  navigateTo(event) {
    const url = event.currentTarget.dataset.url;
    if (url) {
      wx.navigateTo({ url });
    }
  },

  async handleLogout() {
    if (this.data.loggingOut) return;
    const { confirm } = await wx.showModal({
      title: '确认退出',
      content: '退出后将无法接收通知和消息，确认退出登录吗？',
      confirmColor: '#FF3B30'
    });
    if (!confirm) return;
    this.setData({ loggingOut: true });
    wx.showLoading({ title: '退出中' });
    try {
      await logout();
      wx.removeStorageSync('token');
      wx.hideLoading();
      wx.reLaunch({ url: '/pages/profile/index' });
    } catch (error) {
      wx.removeStorageSync('token');
      wx.hideLoading();
      wx.reLaunch({ url: '/pages/profile/index' });
    }
    this.setData({ loggingOut: false });
  }
});