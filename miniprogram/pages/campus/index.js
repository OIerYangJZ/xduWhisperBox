import { getPosts } from '../../api/post';
import { getChannels } from '../../api/posts';
import { getAnnouncements, getColleges } from '../../api/campus';
import { getNotifications } from '../../api/notifications';
import { requireLoginPage } from '../../utils/auth_guard';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' }
];

Page({
  data: {
    currentTab: 'community',
    posts: [],
    news: [],
    colleges: [],
    loading: false,
    hasMore: true,
    page: 1,
    limit: 10,
    channels: ['全部'],
    activeChannel: '全部',
    sortOptions: SORT_OPTIONS,
    activeSort: 'latest',
    unreadCount: 0
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this._didLoadData = true;
    this.loadChannels();
    this.loadUnreadCount();
    this.fetchData();
  },

  onShow() {
    if (!requireLoginPage()) return;
    if (!this._didLoadData) {
      this._didLoadData = true;
      this.loadChannels();
      this.fetchData();
    }
    this.loadUnreadCount();
  },

  onPullDownRefresh() {
    this.setData({
      page: 1,
      posts: [],
      hasMore: true
    }, () => {
      this.fetchData().then(() => wx.stopPullDownRefresh());
    });
  },

  fetchData() {
    const { currentTab } = this.data;
    if (currentTab === 'community') return this.fetchPosts();
    if (currentTab === 'news') return this.fetchNews();
    if (currentTab === 'college') return this.fetchColleges();
    return Promise.resolve();
  },

  async loadChannels() {
    const channels = await getChannels();
    this.setData({ channels: ['全部', ...channels.filter((item) => item !== '全部')] });
  },

  async loadUnreadCount() {
    try {
      const result = await getNotifications();
      this.setData({ unreadCount: result.unreadCount || 0 });
    } catch (error) {}
  },

  switchTab(e) {
    const tab = e.currentTarget.dataset.tab;
    if (this.data.currentTab === tab) return;
    this.setData({
      currentTab: tab,
      posts: [],
      page: 1,
      hasMore: true
    }, () => {
      this.fetchData();
    });
  },

  onChannelTap(event) {
    const channel = event.currentTarget.dataset.channel;
    if (!channel || channel === this.data.activeChannel) return;
    this.setData({ activeChannel: channel, posts: [], page: 1, hasMore: true }, () => this.fetchPosts());
  },

  onSortTap(event) {
    const sort = event.currentTarget.dataset.sort;
    if (!sort || sort === this.data.activeSort) return;
    this.setData({ activeSort: sort, posts: [], page: 1, hasMore: true }, () => this.fetchPosts());
  },

  async fetchPosts() {
    if (this.data.loading || !this.data.hasMore) return;

    this.setData({ loading: true });
    try {
      const res = await getPosts({
        page: this.data.page,
        limit: this.data.limit,
        sort: this.data.activeSort,
        ...(this.data.activeChannel !== '全部' ? { channel: this.data.activeChannel } : {})
      });

      if (res && res.data) {
        const newPosts = res.data.items || [];
        this.setData({
          posts: [...this.data.posts, ...newPosts],
          page: this.data.page + 1,
          hasMore: res.data.hasMore !== undefined ? res.data.hasMore : newPosts.length >= this.data.limit,
          loading: false
        });
      }
    } catch (err) {
      console.error(err);
      this.setData({ loading: false });
    }
  },

  onReachBottom() {
    if (this.data.currentTab === 'community') this.fetchPosts();
  },

  async fetchNews() {
    this.setData({ loading: true });
    try {
      const res = await getAnnouncements();
      if (res && res.data) {
        this.setData({ news: res.data, loading: false });
      }
    } catch (err) {
      this.setData({ loading: false });
    }
  },

  async fetchColleges() {
    this.setData({ loading: true });
    try {
      const res = await getColleges();
      if (res && res.data) {
        this.setData({ colleges: res.data, loading: false });
      }
    } catch (err) {
      this.setData({ loading: false });
    }
  },

  goToDetail(e) {
    const postId = e.currentTarget.dataset.id;
    wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}` });
  },

  goSearch() {
    wx.navigateTo({ url: '/pages/campus/search/index' });
  },

  goCreatePost() {
    wx.navigateTo({ url: '/pages/campus/create-post/index' });
  },

  goNotifications() {
    wx.navigateTo({ url: '/pages/profile/notifications/index' });
  },

  goToNewsDetail(e) {
    const { title, content, createdAt } = e.currentTarget.dataset;
    wx.navigateTo({
      url: `/pages/campus/announcement-detail/index?title=${encodeURIComponent(title || '')}&content=${encodeURIComponent(content || '')}&createdAt=${encodeURIComponent(createdAt || '')}`
    });
  }
});
