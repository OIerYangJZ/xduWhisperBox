import { adminLogin } from '../../../api/admin';

Page({
  data: {
    username: '',
    password: '',
    submitting: false
  },

  onInput(event) {
    const key = event.currentTarget.dataset.key;
    if (key) this.setData({ [key]: event.detail.value });
  },

  async submit() {
    const username = this.data.username.trim();
    const password = this.data.password.trim();
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' });
      return;
    }
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    try {
      const data = await adminLogin(username, password);
      if (data.token) wx.setStorageSync('adminToken', data.token);
      wx.showToast({ title: '登录成功', icon: 'success' });
      setTimeout(() => wx.redirectTo({ url: '/pages/admin/console/index' }), 500);
    } catch (error) {}
    this.setData({ submitting: false });
  }
});
