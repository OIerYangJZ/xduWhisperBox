import { getPosts } from '../../api/post';
import { getAnnouncements, getColleges } from '../../api/campus';
import { requireLoginPage } from '../../utils/auth_guard';

Page({
  data: {
    currentTab: 'community', // 'community' | 'news' | 'college'
    posts: [],
    news: [],
    colleges: [],
    loading: false,
    hasMore: true,
    page: 1,
    limit: 10
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this._didLoadData = true;
    this.fetchData();
  },

  onShow() {
    if (!requireLoginPage()) return;
    if (!this._didLoadData) {
      this._didLoadData = true;
      this.fetchData();
    }
  },

  onPullDownRefresh() {
    this.setData({
      page: 1,
      posts: [],
      hasMore: true
    }, () => {
      this.fetchData().then(() => {
        wx.stopPullDownRefresh();
      });
    });
  },

  fetchData() {
    const { currentTab } = this.data;
    if (currentTab === 'community') return this.fetchPosts();
    if (currentTab === 'news') return this.fetchNews();
    if (currentTab === 'college') return this.fetchColleges();
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

  async fetchPosts() {
    if (this.data.loading || !this.data.hasMore) return;
    
    this.setData({ loading: true });
    try {
      const res = await getPosts({
        page: this.data.page,
        limit: this.data.limit
      });
      
      if (res && res.data) {
        const newPosts = res.data.items || [];
        this.setData({
          posts: [...this.data.posts, ...newPosts],
          hasMore: newPosts.length >= this.data.limit,
          loading: false
        });
      }
    } catch (err) {
      console.error(err);
      this.setData({ loading: false });
    }
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
    wx.navigateTo({
      url: `/pages/campus/post-detail/index?id=${postId}`
    });
  },

  goToNewsDetail(e) {
    // 暂时弹窗展示，后续可增加详情页
    const item = e.currentTarget.dataset.item;
    wx.showModal({
      title: item.title,
      content: item.content,
      showCancel: false
    });
  }
});
