import { getColleges } from '../../../api/campus';
import { getPosts } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    colleges: [],
    activeCollege: '',
    posts: [],
    loading: true
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    if (options && options.name) {
      this.setData({ activeCollege: decodeURIComponent(options.name) });
    }
    this._didLoadData = true;
    this.loadCollege();
  },

  onShow() {
    if (!requireLoginPage()) return;
    if (!this._didLoadData) {
      this._didLoadData = true;
      this.loadCollege();
    }
  },

  async loadCollege() {
    this.setData({ loading: true });
    try {
      const collegesRes = await getColleges();
      const colleges = ((collegesRes && collegesRes.data) || []).map((item) => item.name || item);
      const activeCollege = this.data.activeCollege || colleges[0] || '';
      const posts = activeCollege ? await getPosts({ keyword: activeCollege, sort: 'latest' }) : [];
      this.setData({
        colleges,
        activeCollege,
        posts,
        loading: false
      });
    } catch (error) {
      this.setData({ colleges: [], posts: [], loading: false });
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
