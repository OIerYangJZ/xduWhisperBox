import { getUserInfo } from '../../../api/auth';
import { updatePrivacy } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    form: {
      allowStrangerDm: true,
      showContactable: true
    }
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadProfile();
  },

  async loadProfile() {
    this.setData({ loading: true });
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      this.setData({
        form: {
          allowStrangerDm: profile.allowStrangerDm !== false,
          showContactable: profile.showContactable !== false
        },
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async onPrivacySwitchChange(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    const form = { ...this.data.form, [key]: event.detail.value };
    this.setData({ form });
    try {
      await updatePrivacy({
        allowStrangerDm: form.allowStrangerDm,
        showContactable: form.showContactable
      });
    } catch (error) {
      await this.loadProfile();
    }
  },

  navigateTo(event) {
    const url = event.currentTarget.dataset.url;
    if (url) {
      wx.navigateTo({ url });
    }
  }
});
