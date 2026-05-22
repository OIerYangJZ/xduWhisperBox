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
  const isDark = theme === 'dark';
  const themeClass = isDark ? 'theme-dark' : 'theme-light';
  page.setData({
    themeClass,
    currentTheme: theme,
    currentLanguage: lang,
    t
  });
  wx.setNavigationBarColor({
    frontColor: isDark ? '#ffffff' : '#000000',
    backgroundColor: isDark ? '#000000' : '#ffffff',
    animation: { duration: 100 }
  });
  wx.setTabBarStyle({
    color: '#8E8E93',
    selectedColor: isDark ? '#4DD0E1' : '#155E75',
    backgroundColor: isDark ? '#000000' : '#ffffff',
    borderStyle: isDark ? 'black' : 'white'
  });
};
