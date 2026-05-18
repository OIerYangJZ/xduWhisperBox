import { getAiHomeData } from '../../api/ai';
import { requireLoginPage } from '../../utils/auth_guard';

Page({
  data: {
    loading: true,
    question: '',
    channels: [],
    hotPosts: [],
    prompts: ['如何发匿名树洞？', '怎么举报违规内容？', '最近有哪些求助？', '二手交易怎么找？']
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onShow() {
    requireLoginPage();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const data = await getAiHomeData();
      this.setData({ channels: data.channels.slice(0, 8), hotPosts: data.hotPosts, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  onInput(event) {
    this.setData({ question: event.detail.value });
  },

  ask() {
    const question = this.data.question.trim();
    if (!question) {
      wx.showToast({ title: '请输入问题', icon: 'none' });
      return;
    }
    wx.navigateTo({ url: `/pages/ai/chat/index?q=${encodeURIComponent(question)}` });
  },

  quickAsk(event) {
    const question = event.currentTarget.dataset.question;
    wx.navigateTo({ url: `/pages/ai/chat/index?q=${encodeURIComponent(question)}` });
  },

  goHistory() {
    wx.navigateTo({ url: '/pages/ai/history/index' });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
