import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

const CATEGORIES = [
  { label: '全部', channel: '' },
  { label: '学习', channel: '学习交流' },
  { label: '活动', channel: '活动拼车' },
  { label: '求助', channel: '求助问答' },
  { label: '综合', channel: '综合' }
];

Page({
  data: {
    categories: CATEGORIES,
    activeIndex: 0,
    posts: [],
    loading: true
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
      const category = this.data.categories[this.data.activeIndex];
      const posts = await getPosts({
        sort: 'latest',
        ...(category.channel ? { channel: category.channel } : {})
      });
      this.setData({ posts, loading: false });
    } catch (error) {
      this.setData({ posts: [], loading: false });
    }
  },

  onCategoryTap(event) {
    this.setData({ activeIndex: Number(event.currentTarget.dataset.index || 0) });
    this.loadData();
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  goSearch() {
    wx.navigateTo({ url: '/pages/campus/search/index' });
  }
});
