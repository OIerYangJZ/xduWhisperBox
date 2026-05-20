const THEME_OPTIONS = [
  { label: '跟随系统', value: 'system' },
  { label: '浅色', value: 'light' },
  { label: '深色', value: 'dark' }
];

Page({
  data: {
    themeOptions: THEME_OPTIONS,
    theme: 'system'
  },

  onLoad() {
    this.setData({ theme: wx.getStorageSync('displayTheme') || 'system' });
  },

  onThemeTap(event) {
    const theme = event.currentTarget.dataset.theme;
    if (!theme) return;
    wx.setStorageSync('displayTheme', theme);
    this.setData({ theme });
    wx.showToast({ title: '显示设置已保存', icon: 'success' });
  }
});
