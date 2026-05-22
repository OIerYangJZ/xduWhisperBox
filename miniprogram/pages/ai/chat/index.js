import { getAiConfig, sendAiMessage } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const normalizeAiReply = (response) => {
  const data = response && response.data ? response.data : response || {};
  return String(data.reply || data.answer || data.content || '').trim();
};

const normalizeReferences = (response) => {
  const data = response && response.data ? response.data : response || {};
  const rows = Array.isArray(data.references) ? data.references : [];
  return rows.map((item, index) => ({
    ...item,
    key: `${item.type || 'ref'}-${item.id || index}`,
    title: item.title || (item.type === 'post' ? '相关帖子' : '基础资料')
  }));
};

const saveAiHistory = (question, answer, references = []) => {
  const row = {
    question,
    answer,
    references,
    createdAt: new Date().toISOString()
  };
  const rows = [row, ...(wx.getStorageSync('aiHistory') || [])]
    .filter((item) => item && item.question)
    .slice(0, 30);
  wx.setStorageSync('aiHistory', rows);
};

Page({
  data: {
    chatId: '',
    messages: [
      { id: '1', role: 'assistant', content: '你好！我是西电 AI 助手。你可以问我校园信息，也可以让我检索树洞里的公开讨论。' }
    ],
    inputVal: '',
    isSending: false,
    scrollTop: 0,
    configured: false,
    currentModel: ''
  },

  onLoad(options) {
    applyThemeAndLanguage(this);
    if (options.id) {
      this.setData({ chatId: options.id });
    }
    if (options.q) {
      this.setData({ inputVal: decodeURIComponent(options.q) });
    }
    if (!requireLoginPage()) return;
    this.refreshConfigState();
    if (this.data.inputVal) {
      this._autoSendQueued = true;
      setTimeout(() => this.sendMessage(), 0);
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.refreshConfigState();
    if (this.data.inputVal && this.data.messages.length === 1 && !this.data.isSending && !this._autoSendQueued) {
      this._autoSendQueued = true;
      setTimeout(() => this.sendMessage(), 0);
    }
  },

  onInput(e) {
    this.setData({ inputVal: e.detail.value });
  },

  refreshConfigState() {
    const config = getAiConfig();
    this.setData({
      configured: Boolean(config.apiKey && config.baseUrl && config.model),
      currentModel: config.model || ''
    });
  },

  goSettings() {
    wx.navigateTo({ url: '/pages/profile/ai-settings/index' });
  },

  async sendMessage() {
    const text = this.data.inputVal.trim();
    if (!text || this.data.isSending) return;
    if (!this.data.configured) {
      wx.showToast({ title: '请先配置 AI 接口', icon: 'none' });
      this.goSettings();
      return;
    }
    this._autoSendQueued = false;

    const newMsg = {
      id: Date.now().toString(),
      role: 'user',
      content: text
    };

    this.setData({
      messages: [...this.data.messages, newMsg],
      inputVal: '',
      isSending: true
    }, this.scrollToBottom);

    try {
      const historyMessages = this.data.messages
        .filter((item) => item.role === 'user' || item.role === 'assistant')
        .slice(-8)
        .map((item) => ({ role: item.role, content: item.content }));
      const res = await sendAiMessage(text, { messages: historyMessages });
      const reply = normalizeAiReply(res);
      const references = normalizeReferences(res);
      if (reply) {
        const replyMsg = {
          id: (Date.now() + 1).toString(),
          role: 'assistant',
          content: reply,
          references
        };
        this.setData({
          messages: [...this.data.messages, replyMsg]
        }, this.scrollToBottom);
        saveAiHistory(text, reply, references);
      }
    } catch (err) {
      wx.showToast({ title: 'AI 请求失败，请检查设置', icon: 'none' });
    } finally {
      this.setData({ isSending: false });
    }
  },

  scrollToBottom() {
    wx.createSelectorQuery().select('.chat-list').boundingClientRect(res => {
      if (res) {
        this.setData({
          scrollTop: res.height + 9999
        });
      }
    }).exec();
  }
});
