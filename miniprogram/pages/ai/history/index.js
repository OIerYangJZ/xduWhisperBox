import { formatTime, truncate } from '../../../utils/format';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    rows: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  loadData() {
    const rows = (wx.getStorageSync('aiHistory') || []).map((item) => ({
      ...item,
      questionText: truncate(item.question, 42),
      answerText: truncate(item.answer, 80),
      timeText: formatTime(item.createdAt)
    }));
    this.setData({ rows });
  },

  clearHistory() {
    wx.removeStorageSync('aiHistory');
    this.setData({ rows: [] });
  },

  openChat(event) {
    const question = event.currentTarget.dataset.question;
    wx.navigateTo({ url: `/pages/ai/chat/index?q=${encodeURIComponent(question)}` });
  }
});
