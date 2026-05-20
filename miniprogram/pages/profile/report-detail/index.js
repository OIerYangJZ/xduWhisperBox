import { getReportDetail } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';

const STATUS_TEXT = {
  pending: '待处理',
  resolved: '已处理',
  rejected: '已驳回',
  closed: '已关闭',
  misreport: '恶意举报'
};

Page({
  data: {
    reportId: '',
    report: null,
    loading: true
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    this.setData({ reportId: options.id || '' });
    if (this.data.reportId) this.loadDetail();
  },

  async loadDetail() {
    this.setData({ loading: true });
    try {
      const report = await getReportDetail(this.data.reportId);
      this.setData({
        report: {
          ...report,
          statusText: STATUS_TEXT[report.status] || report.status || '待处理'
        },
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openTarget() {
    const report = this.data.report;
    if (report && report.targetType === 'post' && report.targetId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${report.targetId}` });
    }
  }
});
