import { resetPassword, sendPasswordResetCode } from '../../../api/auth';

Page({
  data: {
    email: '',
    code: '',
    newPassword: '',
    sendingCode: false,
    submitting: false
  },

  onInput(event) {
    const key = event.currentTarget.dataset.key;
    if (key) this.setData({ [key]: event.detail.value });
  },

  async sendCode() {
    const email = this.data.email.trim();
    if (!email) {
      wx.showToast({ title: '请输入邮箱', icon: 'none' });
      return;
    }
    if (this.data.sendingCode) return;
    this.setData({ sendingCode: true });
    try {
      await sendPasswordResetCode(email);
      wx.showToast({ title: '验证码已发送', icon: 'success' });
    } catch (error) {}
    this.setData({ sendingCode: false });
  },

  async submit() {
    const email = this.data.email.trim();
    const code = this.data.code.trim();
    const newPassword = this.data.newPassword.trim();
    if (!email || !code || !newPassword) {
      wx.showToast({ title: '请补全信息', icon: 'none' });
      return;
    }
    if (newPassword.length < 6) {
      wx.showToast({ title: '密码至少 6 位', icon: 'none' });
      return;
    }
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    try {
      await resetPassword(email, code, newPassword);
      wx.showToast({ title: '密码已重置', icon: 'success' });
      setTimeout(() => wx.navigateBack({ fail: () => wx.redirectTo({ url: '/pages/profile/auth/index' }) }), 700);
    } catch (error) {}
    this.setData({ submitting: false });
  }
});
