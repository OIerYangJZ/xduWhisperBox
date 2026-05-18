import { getPosts } from '../../api/post';

Page({
  data: {
    currentTab: 'community', // 'community' | 'news' | 'college'
    posts: [],
    loading: false,
    hasMore: true,
    page: 1,
    limit: 10
  },

  onLoad() {
    this.fetchPosts();
  },

  onPullDownRefresh() {
    this.setData({
      page: 1,
      posts: [],
      hasMore: true
    }, () => {
      this.fetchPosts().then(() => {
        wx.stopPullDownRefresh();
      });
    });
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.setData({ page: this.data.page + 1 }, () => {
        this.fetchPosts();
      });
    }
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
      if (tab === 'community') {
        this.fetchPosts();
      }
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

  goToDetail(e) {
    const postId = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/campus/post-detail/index?id=${postId}`
    });
  }
});
