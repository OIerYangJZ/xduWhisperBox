import { logout } from '../../../api/auth';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: false,
    loggingOut: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    applyThemeAndLanguage(this);
  },

  navigateTo(event) {
    const url = event.currentTarget.dataset.url;
    if (url) {
      wx.navigateTo({ url });
    }
  },

  async handleLogout() {
    if (this.data.loggingOut) return;
    const isEn = this.data.currentLanguage === 'en';
    const { confirm } = await wx.showModal({
      title: this.data.t.logout || '确认退出',
      content: isEn 
        ? 'Are you sure you want to log out?' 
        : '退出后将无法接收通知和消息，确认退出登录吗？',
      confirmColor: '#FF3B30',
      confirmText: isEn ? 'Logout' : '确认',
      cancelText: isEn ? 'Cancel' : '取消'
    });
    if (!confirm) return;
    this.setData({ loggingOut: true });
    wx.showLoading({ title: isEn ? 'Logging out...' : '退出中' });
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