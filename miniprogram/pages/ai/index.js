import { formatTime, truncate } from '../../utils/format';
import { requireLoginPage } from '../../utils/auth_guard';
import { getAiConfig } from '../../api/ai';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

Page({
  data: {
    history: [],
    configured: false,
    currentModel: '',
    subtitleText: '请先配置 OpenAI 兼容接口'
  },

  onLoad() {
    setTimeout(() => {
      if (!requireLoginPage()) return;
      this.loadHistory();
    }, 0);
  },

  onShow() {
    applyThemeAndLanguage(this);
    setTimeout(() => {
      applyThemeAndLanguage(this);
      if (!requireLoginPage()) return;
      this.loadHistory();
    }, 0);
  },

  loadHistory() {
    const config = getAiConfig();
    const rows = (wx.getStorageSync('aiHistory') || []).slice(0, 5).map((item) => ({
      id: item.createdAt || item.question,
      title: truncate(item.question, 28),
      date: formatTime(item.createdAt),
      question: item.question
    }));
    this.setData({
      history: rows,
      configured: Boolean(config.apiKey && config.baseUrl && config.model),
      currentModel: config.model || '',
      subtitleText: config.apiKey && config.baseUrl && config.model
        ? `当前模型：${config.model}`
        : '请先配置 OpenAI 兼容接口'
    });
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
  },

  goToSettings() {
    if (!requireLoginPage()) return;
    wx.navigateTo({
      url: '/pages/profile/ai-settings/index'
    });
  }
});
