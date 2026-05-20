import { getAdminImageReviews, handleAdminImageReview } from '../../../api/admin';

const STATUSES = [
  { label: '待审核', value: 'pending' },
  { label: '风险', value: 'risk' },
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
      const rows = await getAdminImageReviews({
        status: this.data.statuses[this.data.statusIndex].value,
        keyword: this.data.keyword.trim()
      });
      this.setData({ rows, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  preview(event) {
    const url = event.currentTarget.dataset.url;
    if (url) wx.previewImage({ current: url, urls: this.data.rows.map((item) => item.url).filter(Boolean) });
  },

  async handleImage(event) {
    const { id, action } = event.currentTarget.dataset;
    try {
      await handleAdminImageReview(id, action);
      await this.loadData();
    } catch (error) {}
  }
});
