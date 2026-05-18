import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    content: '',
    contact: '',
    submitting: false
  },

  onShow() {
    requireLoginPage();
  },

  onContentInput(event) {
    this.setData({ content: event.detail.value });
  },

  onContactInput(event) {
    this.setData({ contact: event.detail.value });
  },

  submitFeedback() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入反馈内容', icon: 'none' });
      return;
    }
    this.setData({ submitting: true });
    const rows = wx.getStorageSync('feedbackDrafts') || [];
    rows.unshift({
      content,
      contact: this.data.contact.trim(),
      createdAt: new Date().toISOString()
    });
    wx.setStorageSync('feedbackDrafts', rows.slice(0, 20));
    wx.showToast({ title: '已保存反馈', icon: 'success' });
    setTimeout(() => {
      this.setData({ content: '', contact: '', submitting: false });
      wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/profile/index' }) });
    }, 700);
  }
});
