import { getChannels, getPosts } from '../../../api/posts';
import { searchUsers } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' },
  { label: '点赞', value: 'likes' }
];

Page({
  data: {
    keyword: '',
    activeType: 'posts',
    channels: ['全部'],
    activeChannel: '全部',
    sortOptions: SORT_OPTIONS,
    activeSort: 'hot',
    posts: [],
    users: [],
    history: [],
    searched: false,
    loading: false
  },

  onLoad(options) {
    if (options.channel) {
      this.setData({ activeChannel: decodeURIComponent(options.channel) });
    }
    if (options.keyword) {
      this.setData({ keyword: decodeURIComponent(options.keyword) });
    }
    if (!requireLoginPage()) return;
    this.setData({ history: wx.getStorageSync('searchHistory') || [] });
    this.loadChannels();
    if (this.data.keyword) {
      this.search();
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.setData({ history: wx.getStorageSync('searchHistory') || [] });
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
    this.setData({ channels: ['全部', ...channels.filter((item) => item !== '全部')] });
  },

  onChannelTap(event) {
    this.setData({ activeChannel: event.currentTarget.dataset.channel });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  onSortTap(event) {
    this.setData({ activeSort: event.currentTarget.dataset.sort });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  onTypeTap(event) {
    const type = event.currentTarget.dataset.type;
    if (!type || type === this.data.activeType) return;
    this.setData({ activeType: type });
    if (this.data.searched || this.data.keyword.trim()) this.search();
  },

  async search() {
    const keyword = this.data.keyword.trim();
    if (!keyword && this.data.activeChannel === '全部' && this.data.activeType === 'posts') {
      wx.showToast({ title: '请输入关键词', icon: 'none' });
      return;
    }
    if (!keyword && this.data.activeType === 'users') {
      wx.showToast({ title: '请输入用户关键词', icon: 'none' });
      return;
    }
    this.setData({ loading: true, searched: true });
    try {
      let posts = this.data.posts;
      let users = this.data.users;
      if (this.data.activeType === 'posts') {
        posts = await getPosts({
          keyword,
          sort: this.data.activeSort,
          ...(this.data.activeChannel !== '全部' ? { channel: this.data.activeChannel } : {})
        });
      } else {
        users = await searchUsers(keyword);
      }
      const history = keyword
        ? [keyword, ...this.data.history.filter((item) => item !== keyword)].slice(0, 8)
        : this.data.history;
      if (keyword) wx.setStorageSync('searchHistory', history);
      this.setData({ posts, users, history, loading: false });
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
  },

  goUserDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
  }
});
