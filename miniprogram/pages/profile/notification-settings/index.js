import { getUserInfo } from '../../../api/auth';
import { updateNotificationPreferences } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const PREF_KEYS = [
  'notifyComment',
  'notifyReply',
  'notifyLike',
  'notifyFavorite',
  'notifyReportResult',
  'notifySystem'
];

Page({
  data: {
    loading: true,
    prefs: {
      notifyComment: true,
      notifyReply: true,
      notifyLike: true,
      notifyFavorite: true,
      notifyReportResult: true,
      notifySystem: true
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
      const prefs = { ...this.data.prefs };
      PREF_KEYS.forEach((key) => {
        prefs[key] = profile[key] !== false;
      });
      this.setData({ prefs, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async onSwitchChange(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    const prefs = { ...this.data.prefs, [key]: event.detail.value };
    this.setData({ prefs });
    try {
      await updateNotificationPreferences(prefs);
    } catch (error) {
      await this.loadProfile();
    }
  }
});
