import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    keyword: '',
    posts: [],
    history: [],
    searched: false,
    loading: false
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const history = wx.getStorageSync('searchHistory') || [];
    this.setData({ history });
    if (options.keyword) {
      const keyword = decodeURIComponent(options.keyword);
      this.setData({ keyword });
      this.search();
    }
  },

  onShow() {
    requireLoginPage();
  },

  onInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  onHistoryTap(event) {
    this.setData({ keyword: event.currentTarget.dataset.keyword });
    this.search();
  },

  async search() {
    const keyword = this.data.keyword.trim();
    if (!keyword) {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    this.setData({ loading: true, searched: true });
    try {
      const posts = await getPosts({ keyword, sort: 'hot' });
      const history = [keyword, ...this.data.history.filter((item) => item !== keyword)].slice(0, 8);
      wx.setStorageSync('searchHistory', history);
      this.setData({ posts, history, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  clearHistory() {
    wx.removeStorageSync('searchHistory');
    this.setData({ history: [] });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
