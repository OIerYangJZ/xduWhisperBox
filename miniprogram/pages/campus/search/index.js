import { getChannels, getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' },
  { label: '点赞', value: 'likes' }
];

Page({
  data: {
    keyword: '',
    channels: ['全部'],
    activeChannel: '全部',
    sortOptions: SORT_OPTIONS,
    activeSort: 'hot',
    posts: [],
    history: [],
    searched: false,
    loading: false
  },

  onLoad(options) {
    if (options.channel) {
      this.setData({ activeChannel: decodeURIComponent(options.channel) });
    }
    if (options.keyword) {
      const keyword = decodeURIComponent(options.keyword);
      this.setData({ keyword });
    }
    if (!requireLoginPage()) return;
    const history = wx.getStorageSync('searchHistory') || [];
    this.setData({ history });
    this.loadChannels();
    if (this.data.keyword) {
      this.search();
    }
  },

  onShow() {
    if (!requireLoginPage()) return;
    const history = wx.getStorageSync('searchHistory') || [];
    this.setData({ history });
    if (this.data.channels.length <= 1) {
      this.loadChannels();
    }
    if (this.data.keyword && !this.data.searched) {
      this.search();
    }
  },

  onInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  onHistoryTap(event) {
    this.setData({ keyword: event.currentTarget.dataset.keyword });
    this.search();
  },

  async loadChannels() {
    const channels = await getChannels();
    this.setData({
      channels: ['全部', ...channels.filter((item) => item !== '全部')]
    });
  },

  onChannelTap(event) {
    this.setData({ activeChannel: event.currentTarget.dataset.channel });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  onSortTap(event) {
    this.setData({ activeSort: event.currentTarget.dataset.sort });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  async search() {
    const keyword = this.data.keyword.trim();
    if (!keyword && this.data.activeChannel === '全部') {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    this.setData({ loading: true, searched: true });
    try {
      const posts = await getPosts({
        keyword,
        sort: this.data.activeSort,
        ...(this.data.activeChannel !== '全部' ? { channel: this.data.activeChannel } : {})
      });
      const history = keyword
        ? [keyword, ...this.data.history.filter((item) => item !== keyword)].slice(0, 8)
        : this.data.history;
      if (keyword) wx.setStorageSync('searchHistory', history);
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
