import { favoritePost, getChannels, getPosts, togglePostLike, unfavoritePost } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

const SORT_OPTIONS = [
  { label: '最新', value: 'latest' },
  { label: '热度', value: 'hot' },
  { label: '点赞', value: 'likes' }
];

Page({
  data: {
    loading: true,
    channels: ['全部'],
    activeChannel: '全部',
    sortOptions: SORT_OPTIONS,
    activeSort: 'latest',
    keyword: '',
    posts: [],
    errorText: ''
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    if (options.keyword) {
      this.setData({ keyword: decodeURIComponent(options.keyword) });
    }
    this.loadData();
  },

  onShow() {
    requireLoginPage();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true, errorText: '' });
    try {
      const channels = await getChannels();
      const params = {
        sort: this.data.activeSort,
        ...(this.data.activeChannel !== '全部' ? { channel: this.data.activeChannel } : {}),
        ...(this.data.keyword.trim() ? { keyword: this.data.keyword.trim() } : {})
      };
      const posts = await getPosts(params);
      this.setData({
        channels: ['全部', ...channels.filter((item) => item !== '全部')],
        posts,
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false, errorText: '树洞加载失败' });
    }
  },

  onKeywordInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  onSearchConfirm() {
    this.loadData();
  },

  onChannelTap(event) {
    this.setData({ activeChannel: event.currentTarget.dataset.channel });
    this.loadData();
  },

  onSortTap(event) {
    this.setData({ activeSort: event.currentTarget.dataset.sort });
    this.loadData();
  },

  goCreatePost() {
    if (!wx.getStorageSync('token')) {
      wx.navigateTo({ url: '/pages/profile/auth/index' });
      return;
    }
    wx.navigateTo({ url: '/pages/campus/create-post/index' });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  async toggleLike(event) {
    if (!this.requireLogin()) return;
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post) return;
    try {
      const result = await togglePostLike(post.id);
      const liked = Boolean(result.liked);
      const posts = this.data.posts.slice();
      posts[index] = {
        ...post,
        liked,
        likeCount: Math.max(0, post.likeCount + (liked ? 1 : -1))
      };
      this.setData({ posts });
    } catch (error) {}
  },

  async toggleFavorite(event) {
    if (!this.requireLogin()) return;
    const index = Number(event.currentTarget.dataset.index);
    const post = this.data.posts[index];
    if (!post) return;
    try {
      const result = post.favorited ? await unfavoritePost(post.id) : await favoritePost(post.id);
      const posts = this.data.posts.slice();
      posts[index] = {
        ...post,
        favorited: Boolean(result.favorited),
        favoriteCount: Number(result.favoriteCount || post.favoriteCount)
      };
      this.setData({ posts });
    } catch (error) {}
  },

  requireLogin() {
    if (wx.getStorageSync('token')) return true;
    wx.navigateTo({ url: '/pages/profile/auth/index' });
    return false;
  }
});
