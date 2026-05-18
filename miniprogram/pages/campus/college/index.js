import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

const COLLEGES = [
  '通信工程学院',
  '电子工程学院',
  '计算机科学与技术学院',
  '人工智能学院',
  '网络与信息安全学院',
  '微电子学院',
  '机电工程学院',
  '经济与管理学院'
];

Page({
  data: {
    colleges: COLLEGES,
    activeCollege: COLLEGES[0],
    posts: [],
    loading: true
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this.loadCollege();
  },

  onShow() {
    requireLoginPage();
  },

  async loadCollege() {
    this.setData({ loading: true });
    try {
      const posts = await getPosts({ keyword: this.data.activeCollege, sort: 'latest' });
      this.setData({ posts, loading: false });
    } catch (error) {
      this.setData({ posts: [], loading: false });
    }
  },

  onCollegeTap(event) {
    this.setData({ activeCollege: event.currentTarget.dataset.name });
    this.loadCollege();
  },

  askCollege() {
    wx.navigateTo({
      url: `/pages/ai/chat/index?q=${encodeURIComponent(`${this.data.activeCollege} 有哪些近期讨论？`)}`
    });
  },

  searchCollege() {
    wx.navigateTo({
      url: `/pages/campus/search/index?keyword=${encodeURIComponent(this.data.activeCollege)}`
    });
  },

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  }
});
