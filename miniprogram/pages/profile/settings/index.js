import { getUserInfo, logout } from '../../../api/auth';
import { updateNotificationPreferences } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';

const PREF_KEYS = [
  'notifyComment',
  'notifyReply',
  'notifyLike',
  'notifyFavorite',
  'notifyReportResult',
  'notifySystem'
];

Page({
  data: {
    loading: true,
    profile: null,
    prefs: {
      notifyComment: true,
      notifyReply: true,
      notifyLike: true,
      notifyFavorite: true,
      notifyReportResult: true,
      notifySystem: true
    },
    loggingOut: false
  },

  onShow() {
    if (!requireLoginPage()) return;
    this.loadProfile();
  },

  async loadProfile() {
    if (!requireLoginPage()) return;
    this.setData({ loading: true });
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      const prefs = { ...this.data.prefs };
      PREF_KEYS.forEach((key) => {
        prefs[key] = profile[key] !== false;
      });
      this.setData({ profile, prefs, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async onSwitchChange(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    const prefs = { ...this.data.prefs, [key]: event.detail.value };
    this.setData({ prefs });
    try {
      await updateNotificationPreferences(prefs);
    } catch (error) {
      await this.loadProfile();
    }
  },

  async handleLogout() {
    if (this.data.loggingOut) return;
    this.setData({ loggingOut: true });
    try {
      await logout();
    } catch (error) {}
    wx.removeStorageSync('token');
    this.setData({ loggingOut: false });
    wx.showToast({ title: '已退出登录', icon: 'success' });
    setTimeout(() => wx.switchTab({ url: '/pages/profile/index' }), 600);
  }
});
