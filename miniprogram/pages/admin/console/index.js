import { adminLogout, getAdminOverview } from '../../../api/admin';

Page({
  data: {
    loading: true,
    overview: null,
    cards: []
  },

  onShow() {
    if (!wx.getStorageSync('adminToken')) {
      wx.redirectTo({ url: '/pages/admin/login/index' });
      return;
    }
    this.loadOverview();
  },

  async loadOverview() {
    this.setData({ loading: true });
    try {
      const overview = await getAdminOverview();
      const cards = [
        { label: '待审核内容', value: overview.pendingReviewCount || overview.pendingReviews || 0, page: 'reviews' },
        { label: '待处理举报', value: overview.pendingReportCount || overview.pendingReports || 0, page: 'reports' },
        { label: '待审图片', value: overview.pendingImageCount || overview.pendingImages || 0, page: 'images' }
      ];
      this.setData({ overview, cards, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openPage(event) {
    const page = event.currentTarget.dataset.page;
    if (page) wx.navigateTo({ url: `/pages/admin/${page}/index` });
  },

  async logout() {
    try {
      await adminLogout();
    } catch (error) {}
    wx.removeStorageSync('adminToken');
    wx.redirectTo({ url: '/pages/admin/login/index' });
  }
});
