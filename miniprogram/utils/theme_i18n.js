import { getTranslation, getLanguage } from './i18n';

export const getDisplayTheme = () => {
  const config = wx.getStorageSync('displayTheme') || 'system';
  if (config === 'system') {
    try {
      const appBase = wx.getAppBaseInfo();
      return appBase.theme || 'light';
    } catch (e) {
      return 'light';
    }
  }
  return config;
};

export const applyThemeAndLanguage = (page) => {
  const theme = getDisplayTheme();
  const lang = getLanguage();
  const t = getTranslation(lang);
  page.setData({
    themeClass: theme === 'dark' ? 'theme-dark' : 'theme-light',
    currentTheme: theme,
    currentLanguage: lang,
    t
  });
  // Dynamic navigation bar styling
  if (theme === 'dark') {
    wx.setNavigationBarColor({
      frontColor: '#ffffff',
      backgroundColor: '#1c1c1e',
      animation: { duration: 100 }
    });
  } else {
    wx.setNavigationBarColor({
      frontColor: '#000000',
      backgroundColor: '#ffffff',
      animation: { duration: 100 }
    });
  }
};
