import { requireLoginPage } from '../../../utils/auth_guard';
import { submitFeedback } from '../../../api/user';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    content: '',
    contact: '',
    submitting: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    requireLoginPage();
  },

  onContentInput(event) {
    this.setData({ content: event.detail.value });
  },

  onContactInput(event) {
    this.setData({ contact: event.detail.value });
  },

  async submitFeedback() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入反馈内容', icon: 'none' });
      return;
    }
    this.setData({ submitting: true });
    try {
      await submitFeedback({
        content,
        contact: this.data.contact.trim()
      });
      wx.showToast({ title: '已提交反馈', icon: 'success' });
      this.setData({ content: '', contact: '', submitting: false });
      setTimeout(() => {
        wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/profile/index' }) });
      }, 700);
    } catch (error) {
      this.setData({ submitting: false });
    }
  }
});
