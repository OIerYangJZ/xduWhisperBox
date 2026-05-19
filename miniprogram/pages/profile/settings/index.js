import { getUserInfo, logout } from '../../../api/auth';
import { uploadAvatarImage } from '../../../api/uploads';
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
    loggingOut: false,
    uploadingAvatar: false
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

  chooseAvatar() {
    if (this.data.uploadingAvatar) return;
    const onPicked = async (filePath) => {
      if (!filePath) return;
      this.setData({ uploadingAvatar: true });
      wx.showLoading({ title: '上传中' });
      try {
        const result = await uploadAvatarImage(filePath);
        this.setData({
          profile: {
            ...this.data.profile,
            avatarUrl: result.avatarUrl
          },
          uploadingAvatar: false
        });
        wx.hideLoading();
        wx.showToast({ title: '头像已更新', icon: 'success' });
      } catch (error) {
        wx.hideLoading();
        this.setData({ uploadingAvatar: false });
      }
    };

    if (wx.chooseMedia) {
      wx.chooseMedia({
        count: 1,
        mediaType: ['image'],
        sizeType: ['compressed'],
        sourceType: ['album', 'camera'],
        success: (res) => {
          const file = (res.tempFiles || [])[0];
          onPicked(file && file.tempFilePath);
        }
      });
      return;
    }

    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => onPicked((res.tempFilePaths || [])[0])
    });
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
