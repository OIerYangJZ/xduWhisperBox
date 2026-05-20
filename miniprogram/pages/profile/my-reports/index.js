import { getMyReports } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';

const STATUS_TEXT = {
  pending: '待处理',
  resolved: '已处理',
  rejected: '已驳回',
  closed: '已关闭'
};

Page({
  data: {
    loading: true,
    reports: []
  },

  onShow() {
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const reports = (await getMyReports()).map((item) => ({
        ...item,
        statusText: STATUS_TEXT[item.status] || item.status || '待处理'
      }));
      this.setData({ reports, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openTarget(event) {
    const item = this.data.reports[Number(event.currentTarget.dataset.index)];
    if (item && item.targetType === 'post' && item.targetId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${item.targetId}` });
    }
  }
});
