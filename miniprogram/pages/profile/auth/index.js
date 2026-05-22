import { login } from '../../../api/auth';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    identifier: '',
    password: ''
  },

  onIdentifierInput(e) {
    this.setData({ identifier: e.detail.value });
  },

  onPasswordInput(e) {
    this.setData({ password: e.detail.value });
  },

  async handleLogin() {
    const { identifier, password } = this.data;
    if (!identifier || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' });
      return;
    }

    wx.showLoading({ title: '登录中' });
    try {
      const res = await login(identifier, password);
      wx.hideLoading();
      if (res && res.data && res.data.token) {
        wx.setStorageSync('token', res.data.token);
        wx.showToast({ title: '登录成功', icon: 'success' });
        setTimeout(() => {
          wx.navigateBack({
            delta: 1,
            fail: () => wx.switchTab({ url: '/pages/profile/index' })
          });
        }, 1500);
      } else if (res && res.data && res.data.needVerify) {
        wx.showModal({
          title: '需要邮箱验证',
          content: '账号尚未完成邮箱验证，是否现在验证？',
          success: (modal) => {
            if (modal.confirm) {
              wx.navigateTo({
                url: `/pages/profile/register/index?email=${encodeURIComponent(res.data.email || '')}&password=${encodeURIComponent(password)}&debugCode=${encodeURIComponent(res.data.debugCode || '')}`
              });
            }
          }
        });
      }
    } catch (err) {
      wx.hideLoading();
      console.error(err);
    }
  },

  handleRegister() {
    wx.navigateTo({ url: '/pages/profile/register/index' });
  },

  handleResetPassword() {
    wx.navigateTo({ url: '/pages/profile/reset-password/index' });
  }
});
