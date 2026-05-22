import { register, verifyEmail } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    nickname: '',
    email: '',
    password: '',
    code: '',
    debugCode: '',
    sending: false,
    verifying: false,
    needVerify: false
  },

  onLoad(options) {
    this.setData({
      email: options.email ? decodeURIComponent(options.email) : '',
      password: options.password ? decodeURIComponent(options.password) : '',
      debugCode: options.debugCode ? decodeURIComponent(options.debugCode) : '',
      needVerify: Boolean(options.email)
    });
  },

  onNicknameInput(event) {
    this.setData({ nickname: event.detail.value });
  },

  onEmailInput(event) {
    this.setData({ email: event.detail.value });
  },

  onPasswordInput(event) {
    this.setData({ password: event.detail.value });
  },

  onCodeInput(event) {
    this.setData({ code: event.detail.value });
  },

  async submitRegister() {
    if (this.data.sending) return;
    const email = this.data.email.trim();
    const password = this.data.password.trim();
    const nickname = this.data.nickname.trim();
    if (!email || !password || !nickname) {
      wx.showToast({ title: '请完整填写注册信息', icon: 'none' });
      return;
    }
    this.setData({ sending: true });
    wx.showLoading({ title: '提交中' });
    try {
      const res = await register({ email, password, nickname });
      wx.hideLoading();
      const data = res.data || {};
      this.setData({
        sending: false,
        needVerify: true,
        debugCode: data.debugCode || ''
      });
      wx.showToast({ title: '验证码已发送', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      this.setData({ sending: false });
    }
  },

  async submitVerify() {
    if (this.data.verifying) return;
    const email = this.data.email.trim();
    const code = this.data.code.trim();
    const password = this.data.password.trim();
    if (!email || code.length !== 6) {
      wx.showToast({ title: '请输入 6 位验证码', icon: 'none' });
      return;
    }
    this.setData({ verifying: true });
    wx.showLoading({ title: '验证中' });
    try {
      const res = await verifyEmail(email, code, password);
      wx.hideLoading();
      if (res && res.data && res.data.token) {
        wx.setStorageSync('token', res.data.token);
        wx.showToast({ title: '已登录', icon: 'success' });
        setTimeout(() => wx.switchTab({ url: '/pages/profile/index' }), 700);
      }
    } catch (error) {
      wx.hideLoading();
      this.setData({ verifying: false });
    }
  }
});
