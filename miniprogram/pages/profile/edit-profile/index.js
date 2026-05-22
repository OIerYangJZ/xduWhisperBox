import { getUserInfo } from '../../../api/auth';
import { uploadAvatarImage, uploadBackgroundImage } from '../../../api/uploads';
import { updateProfile } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    profile: null,
    form: {
      nickname: '',
      studentId: '',
      bio: '',
      gender: ''
    },
    savingProfile: false,
    uploadingAvatar: false,
    uploadingBackground: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    applyThemeAndLanguage(this);
    this.loadProfile();
  },

  async loadProfile() {
    this.setData({ loading: true });
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      this.setData({
        profile,
        form: {
          nickname: profile.nickname || profile.alias || '',
          studentId: profile.studentId || '',
          bio: profile.bio || '',
          gender: profile.gender || ''
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

  chooseAvatar() {
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: async (res) => {
        const tempPath = res.tempFilePaths[0];
        if (!tempPath) return;
        this.setData({ uploadingAvatar: true });
        wx.showLoading({ title: '上传中' });
        try {
          const uploadRes = await uploadAvatarImage(tempPath);
          await this.loadProfile();
          wx.hideLoading();
          wx.showToast({ title: '头像已更新', icon: 'success' });
        } catch (error) {
          wx.hideLoading();
        }
        this.setData({ uploadingAvatar: false });
      }
    });
  },

  chooseBackground() {
    wx.chooseImage({
      count: 1,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: async (res) => {
        const tempPath = res.tempFilePaths[0];
        if (!tempPath) return;
        this.setData({ uploadingBackground: true });
        wx.showLoading({ title: '上传中' });
        try {
          const uploadRes = await uploadBackgroundImage(tempPath);
          // Update profile immediately to persist the background image url and keep other fields
          await updateProfile({
            nickname: this.data.form.nickname.trim(),
            bio: this.data.form.bio.trim(),
            gender: this.data.form.gender === '未设置' ? '' : (this.data.form.gender || ''),
            avatarUrl: this.data.profile.avatarUrl || '',
            backgroundImageUrl: uploadRes.url || ''
          });
          await this.loadProfile();
          wx.hideLoading();
          wx.showToast({ title: '背景已更新', icon: 'success' });
        } catch (error) {
          wx.hideLoading();
        }
        this.setData({ uploadingBackground: false });
      }
    });
  },

  async saveProfile() {
    if (this.data.savingProfile) return;
    
    const nickname = this.data.form.nickname.trim();
    const bio = this.data.form.bio.trim();
    let gender = this.data.form.gender || '';
    if (gender === '未设置') gender = '';

    if (bio.length > 100) {
      wx.showToast({ title: '个性签名不能超过100个字符', icon: 'none' });
      return;
    }

    this.setData({ savingProfile: true });
    wx.showLoading({ title: '保存中' });
    try {
      await updateProfile({
        nickname,
        bio,
        gender,
        avatarUrl: this.data.profile.avatarUrl || '',
        backgroundImageUrl: this.data.profile.backgroundImageUrl || ''
      });
      wx.hideLoading();
      wx.showToast({ title: '资料已保存', icon: 'success' });
      await this.loadProfile();
    } catch (error) {
      wx.hideLoading();
      // Error message is already shown by request.js
    }
    this.setData({ savingProfile: false });
  }
});