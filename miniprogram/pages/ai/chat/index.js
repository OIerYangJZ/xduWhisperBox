import { askCampusAssistant } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    input: '',
    messages: [],
    loading: false
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const question = options.q ? decodeURIComponent(options.q) : '';
    if (question) {
      this.askQuestion(question);
    }
  },

  onShow() {
    requireLoginPage();
  },

  onInput(event) {
    this.setData({ input: event.detail.value });
  },

  send() {
    const question = this.data.input.trim();
    if (!question) {
      wx.showToast({ title: '请输入问题', icon: 'none' });
      return;
    }
    this.setData({ input: '' });
    this.askQuestion(question);
  },

  async askQuestion(question) {
    if (this.data.loading) return;
    const messages = [
      ...this.data.messages,
      { role: 'user', content: question }
    ];
    this.setData({ messages, loading: true });
    try {
      const result = await askCampusAssistant(question);
      const nextMessages = [
        ...messages,
        {
          role: 'assistant',
          content: result.answer,
          hint: result.hint,
          sources: result.sources
        }
      ];
      this.setData({ messages: nextMessages, loading: false });
      this.saveHistory(question, result.answer);
    } catch (error) {
      this.setData({
        messages: [
          ...messages,
          { role: 'assistant', content: '服务暂时不可用，请稍后再试。', sources: [] }
        ],
        loading: false
      });
    }
  },

  saveHistory(question, answer) {
    const rows = wx.getStorageSync('aiHistory') || [];
    rows.unshift({
      question,
      answer,
      createdAt: new Date().toISOString()
    });
    wx.setStorageSync('aiHistory', rows.slice(0, 50));
  },

  openSource(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
