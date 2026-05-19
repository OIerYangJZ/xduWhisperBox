import { sendAiMessage } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';

const normalizeAiReply = (response) => {
  const data = response && response.data ? response.data : response || {};
  return String(data.reply || data.answer || data.content || '').trim();
};

const saveAiHistory = (question, answer) => {
  const row = {
    question,
    answer,
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
      { id: '1', role: 'assistant', content: '你好！我是西电 AI 助手，有什么可以帮到你的？你可以问我选课、班车、奖学金等校园政策问题。' }
    ],
    inputVal: '',
    isSending: false,
    scrollTop: 0
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ chatId: options.id });
    }
    if (options.q) {
      this.setData({ inputVal: decodeURIComponent(options.q) });
    }
    if (!requireLoginPage()) return;
    if (this.data.inputVal) {
      this._autoSendQueued = true;
      setTimeout(() => this.sendMessage(), 0);
    }
  },

  onShow() {
    if (!requireLoginPage()) return;
    if (this.data.inputVal && this.data.messages.length === 1 && !this.data.isSending && !this._autoSendQueued) {
      this._autoSendQueued = true;
      setTimeout(() => this.sendMessage(), 0);
    }
  },

  onInput(e) {
    this.setData({ inputVal: e.detail.value });
  },

  async sendMessage() {
    const text = this.data.inputVal.trim();
    if (!text || this.data.isSending) return;
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
      const res = await sendAiMessage(text);
      const reply = normalizeAiReply(res);
      if (reply) {
        const replyMsg = {
          id: (Date.now() + 1).toString(),
          role: 'assistant',
          content: reply
        };
        this.setData({
          messages: [...this.data.messages, replyMsg]
        }, this.scrollToBottom);
        saveAiHistory(text, reply);
      }
    } catch (err) {
      wx.showToast({ title: '网络异常，请重试', icon: 'none' });
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
