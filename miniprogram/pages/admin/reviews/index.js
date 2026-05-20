import { getAdminReviews, handleAdminReview, handleAdminReviewBatch } from '../../../api/admin';

const TYPES = [
  { label: '帖子', value: 'post' },
  { label: '评论', value: 'comment' }
];
const STATUSES = [
  { label: '待审核', value: 'pending' },
  { label: '全部', value: 'all' }
];

Page({
  data: {
    types: TYPES,
    statuses: STATUSES,
    typeIndex: 0,
    statusIndex: 0,
    keyword: '',
    loading: true,
    rows: [],
    selectedIds: []
  },

  onShow() {
    this.loadData();
  },

  onInput(event) {
    this.setData({ keyword: event.detail.value });
  },

  onTypeChange(event) {
    this.setData({ typeIndex: Number(event.detail.value || 0), selectedIds: [] });
    this.loadData();
  },

  onStatusChange(event) {
    this.setData({ statusIndex: Number(event.detail.value || 0), selectedIds: [] });
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const rows = (await getAdminReviews({
        type: this.data.types[this.data.typeIndex].value,
        status: this.data.statuses[this.data.statusIndex].value,
        keyword: this.data.keyword.trim()
      })).map((item) => ({ ...item, selected: false }));
      this.setData({ rows, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  toggleSelected(event) {
    const id = event.currentTarget.dataset.id;
    const selectedIds = this.data.selectedIds.slice();
    const rows = this.data.rows.map((item) => ({ ...item }));
    const index = selectedIds.indexOf(id);
    if (index >= 0) selectedIds.splice(index, 1);
    else selectedIds.push(id);
    rows.forEach((item) => {
      item.selected = selectedIds.indexOf(item.id) >= 0;
    });
    this.setData({ selectedIds, rows });
  },

  async handleOne(event) {
    const { id, action } = event.currentTarget.dataset;
    try {
      await handleAdminReview(this.data.types[this.data.typeIndex].value, id, action);
      await this.loadData();
    } catch (error) {}
  },

  async handleBatch(event) {
    const action = event.currentTarget.dataset.action;
    if (!this.data.selectedIds.length) {
      wx.showToast({ title: '请选择内容', icon: 'none' });
      return;
    }
    try {
      const targetType = this.data.types[this.data.typeIndex].value;
      await handleAdminReviewBatch(this.data.selectedIds.map((id) => ({ type: targetType, id, action })));
      this.setData({ selectedIds: [] });
      await this.loadData();
    } catch (error) {}
  }
});
