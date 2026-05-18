import { sendAiMessage } from '../../../api/ai';

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
      // 如果传入了 id，可以发起请求获取该对话的历史记录
    }
  },

  onInput(e) {
    this.setData({ inputVal: e.detail.value });
  },

  async sendMessage() {
    const text = this.data.inputVal.trim();
    if (!text || this.data.isSending) return;

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
      if (res && res.data) {
        const replyMsg = {
          id: (Date.now() + 1).toString(),
          role: 'assistant',
          content: res.data.reply
        };
        this.setData({
          messages: [...this.data.messages, replyMsg]
        }, this.scrollToBottom);
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
