import { fetchDmRequests, handleDmRequest } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    requests: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const requests = await fetchDmRequests();
      this.setData({ requests, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async handleRequest(event) {
    const { id, accept } = event.currentTarget.dataset;
    if (!id) return;
    try {
      await handleDmRequest(id, accept === '1');
      await this.loadData();
    } catch (error) {}
  }
});
