import { getAdminReports, handleAdminReport } from '../../../api/admin';

const STATUSES = [
  { label: '待处理', value: 'pending' },
  { label: '全部', value: 'all' }
];

Page({
  data: {
    statuses: STATUSES,
    statusIndex: 0,
    keyword: '',
    loading: true,
    rows: []
  },

  onShow() {
    this.loadData();
  },

  onInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  onStatusChange(event) {
    this.setData({ statusIndex: Number(event.detail.value || 0) });
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const rows = await getAdminReports({
        status: this.data.statuses[this.data.statusIndex].value,
        keyword: this.data.keyword.trim()
      });
      this.setData({ rows, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  handleReport(event) {
    const { id, action } = event.currentTarget.dataset;
    wx.showModal({
      title: action === 'resolve' ? '处理举报' : '标记误报',
      editable: true,
      placeholderText: '处理说明',
      confirmText: '提交',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await handleAdminReport(id, action, String(res.content || '').trim());
          await this.loadData();
        } catch (error) {}
      }
    });
  }
});
