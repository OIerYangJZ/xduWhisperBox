import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
import { setLanguage, getLanguage } from '../../../utils/i18n';

Page({
  data: {
    themeOptions: [],
    langOptions: [],
    currentThemeOption: 'system'
  },

  onShow() {
    applyThemeAndLanguage(this);
    this.updateOptionsAndApply();
  },

  updateOptionsAndApply() {
    applyThemeAndLanguage(this);
    const t = this.data.t;
    const themeConfig = wx.getStorageSync('displayTheme') || 'system';

    this.setData({
      currentThemeOption: themeConfig,
      themeOptions: [
        { label: t.theme_system || '跟随系统', value: 'system' },
        { label: t.theme_light || '浅色', value: 'light' },
        { label: t.theme_dark || '深色', value: 'dark' }
      ],
      langOptions: [
        { label: t.lang_cn || '简体中文', value: 'zh-CN' },
        { label: t.lang_tw || '繁體中文', value: 'zh-TW' },
        { label: t.lang_en || 'English', value: 'en' }
      ]
    });
  },

  onThemeTap(event) {
    const theme = event.currentTarget.dataset.theme;
    if (!theme) return;
    wx.setStorageSync('displayTheme', theme);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  },

  onLangTap(event) {
    const lang = event.currentTarget.dataset.lang;
    if (!lang) return;
    setLanguage(lang);
    this.updateOptionsAndApply();
    wx.showToast({ title: this.data.t.save_success || '已保存', icon: 'success' });
  }
});
