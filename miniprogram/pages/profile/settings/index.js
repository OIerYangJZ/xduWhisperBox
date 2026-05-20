import { getUserInfo, logout } from '../../../api/auth';
import { uploadAvatarImage, uploadBackgroundImage } from '../../../api/uploads';
import {
  submitCancellationRequest,
  submitLevelUpgradeRequest,
  updateNotificationPreferences,
  updatePrivacy,
  updateProfile
} from '../../../api/user';
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
    form: {
      nickname: '',
      studentId: '',
      bio: '',
      gender: '',
      allowStrangerDm: true,
      showContactable: true
    },
    savingProfile: false,
    submittingCancellation: false,
    submittingLevelUpgrade: false,
    loggingOut: false,
    uploadingAvatar: false,
    uploadingBackground: false
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
      this.setData({
        profile,
        prefs,
        form: {
          nickname: profile.nickname || profile.alias || '',
          studentId: profile.studentId || '',
          bio: profile.bio || '',
          gender: profile.gender || '',
          allowStrangerDm: profile.allowStrangerDm !== false,
          showContactable: profile.showContactable !== false
        },
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  onProfileInput(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    this.setData({ [`form.${key}`]: event.detail.value });
  },

  onGenderChange(event) {
    const values = ['', '男', '女'];
    const index = Number(event.detail.value);
    this.setData({ 'form.gender': values[index] || '' });
  },

  async saveProfile() {
    if (this.data.savingProfile) return;
    this.setData({ savingProfile: true });
    try {
      await updateProfile({
        nickname: this.data.form.nickname.trim(),
        studentId: this.data.form.studentId.trim(),
        bio: this.data.form.bio.trim(),
        gender: this.data.form.gender
      });
      wx.showToast({ title: '资料已保存', icon: 'success' });
      await this.loadProfile();
    } catch (error) {
      this.setData({ savingProfile: false });
      return;
    }
    this.setData({ savingProfile: false });
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

  async onPrivacySwitchChange(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    const form = { ...this.data.form, [key]: event.detail.value };
    this.setData({ form });
    try {
      await updatePrivacy({
        allowStrangerDm: form.allowStrangerDm,
        showContactable: form.showContactable
      });
    } catch (error) {
      await this.loadProfile();
    }
  },

  requestCancellation() {
    if (this.data.submittingCancellation) return;
    wx.showModal({
      title: '账号注销申请',
      editable: true,
      placeholderText: '请填写注销原因',
      confirmText: '提交',
      success: async (res) => {
        if (!res.confirm) return;
        const reason = String(res.content || '').trim();
        if (!reason) {
          wx.showToast({ title: '请填写注销原因', icon: 'none' });
          return;
        }
        this.setData({ submittingCancellation: true });
        try {
          await submitCancellationRequest({ reason });
          wx.showToast({ title: '已提交申请', icon: 'success' });
          await this.loadProfile();
        } catch (error) {}
        this.setData({ submittingCancellation: false });
      }
    });
  },

  requestLevelUpgrade() {
    if (this.data.submittingLevelUpgrade) return;
    wx.showModal({
      title: '一级用户升级申请',
      editable: true,
      placeholderText: '请填写申请理由',
      confirmText: '提交',
      success: async (res) => {
        if (!res.confirm) return;
        const reason = String(res.content || '').trim();
        if (!reason) {
          wx.showToast({ title: '请填写申请理由', icon: 'none' });
          return;
        }
        this.setData({ submittingLevelUpgrade: true });
        try {
          await submitLevelUpgradeRequest({ reason });
          wx.showToast({ title: '已提交申请', icon: 'success' });
          await this.loadProfile();
        } catch (error) {}
        this.setData({ submittingLevelUpgrade: false });
      }
    });
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

  chooseBackground() {
    if (this.data.uploadingBackground) return;
    const onPicked = async (filePath) => {
      if (!filePath) return;
      this.setData({ uploadingBackground: true });
      wx.showLoading({ title: '上传中' });
      try {
        const result = await uploadBackgroundImage(filePath);
        await updateProfile({ backgroundImageUrl: result.url });
        this.setData({
          profile: {
            ...this.data.profile,
            backgroundImageUrl: result.url
          },
          uploadingBackground: false
        });
        wx.hideLoading();
        wx.showToast({ title: '背景图已更新', icon: 'success' });
      } catch (error) {
        wx.hideLoading();
        this.setData({ uploadingBackground: false });
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

  goResetPassword() {
    wx.navigateTo({ url: '/pages/profile/reset-password/index' });
  },

  goDisplaySettings() {
    wx.navigateTo({ url: '/pages/profile/display-settings/index' });
  },

  goAbout() {
    wx.navigateTo({ url: '/pages/profile/about/index' });
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
