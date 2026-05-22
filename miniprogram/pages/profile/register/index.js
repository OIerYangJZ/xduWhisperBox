import { sendCode, verifyEmail } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const EMAIL_SUFFIX = '@stu.xidian.edu.cn';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    studentId: '',
    emailSuffix: EMAIL_SUFFIX,
    code: '',
    debugCode: '',
    sendingCode: false,
    verifying: false,
    codeSent: false
  },

  onLoad(options) {
    const email = options.email ? decodeURIComponent(options.email) : '';
    this.setData({
      studentId: email ? email.split('@')[0] : '',
      debugCode: options.debugCode ? decodeURIComponent(options.debugCode) : '',
      codeSent: Boolean(options.email)
    });
  },

  onStudentIdInput(event) {
    this.setData({ studentId: event.detail.value });
  },

  onCodeInput(event) {
    this.setData({ code: event.detail.value });
  },

  buildEmail() {
    const studentId = this.data.studentId.trim();
    return studentId ? `${studentId}${EMAIL_SUFFIX}` : '';
  },

  async submitSendCode() {
    if (this.data.sendingCode) return;
    const email = this.buildEmail();
    if (!email) {
      wx.showToast({ title: '请输入学号', icon: 'none' });
      return;
    }
    this.setData({ sendingCode: true });
    wx.showLoading({ title: '发送中' });
    try {
      const res = await sendCode(email);
      wx.hideLoading();
      const data = res.data || {};
      this.setData({
        sendingCode: false,
        codeSent: true,
        debugCode: data.debugCode || ''
      });
      wx.showToast({ title: '验证码已发送', icon: 'success' });
    } catch (error) {
      wx.hideLoading();
      this.setData({ sendingCode: false });
    }
  },

  async submitVerify() {
    if (this.data.verifying) return;
    const email = this.buildEmail();
    const code = this.data.code.trim();
    if (!email || code.length !== 6) {
      wx.showToast({ title: '请输入 6 位验证码', icon: 'none' });
      return;
    }
    this.setData({ verifying: true });
    wx.showLoading({ title: '验证中' });
    try {
      const res = await verifyEmail(email, code);
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
