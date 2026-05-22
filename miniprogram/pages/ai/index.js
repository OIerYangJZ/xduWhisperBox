import { formatTime, truncate } from '../../utils/format';
import { requireLoginPage } from '../../utils/auth_guard';

Page({
  data: {
    history: []
  },

  onLoad() {
    setTimeout(() => {
      if (!requireLoginPage()) return;
      this.loadHistory();
    }, 0);
  },

  onShow() {
    setTimeout(() => {
      if (!requireLoginPage()) return;
      this.loadHistory();
    }, 0);
  },

  loadHistory() {
    const rows = (wx.getStorageSync('aiHistory') || []).slice(0, 5).map((item) => ({
      id: item.createdAt || item.question,
      title: truncate(item.question, 28),
      date: formatTime(item.createdAt),
      question: item.question
    }));
    this.setData({ history: rows });
  },

  startNewChat() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/ai/chat/index'
    });
  },

  continueChat(e) {
    if (!requireLoginPage()) return;
    const id = e.currentTarget.dataset.id;
    const question = e.currentTarget.dataset.question || '';
    wx.navigateTo({
      url: `/pages/ai/chat/index?id=${encodeURIComponent(id)}&q=${encodeURIComponent(question)}`
    });
  },

  goToHistory() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/ai/history/index'
    });
  }
});
