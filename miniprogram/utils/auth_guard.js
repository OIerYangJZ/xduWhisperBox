const LOGIN_PAGE = '/pages/profile/auth/index';

const isLoginRoute = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return false;
  const route = `/${current.route || ''}`;
  return route === LOGIN_PAGE || route === '/pages/profile/register/index';
};

export const hasLogin = () => {
  return Boolean(wx.getStorageSync('token'));
};

export const requireLoginPage = () => {
  if (hasLogin()) return true;
  if (!isLoginRoute()) {
    wx.navigateTo({ url: LOGIN_PAGE });
  }
  return false;
};

export const clearLoginAndRedirect = () => {
  wx.removeStorageSync('token');
  if (!isLoginRoute()) {
    wx.navigateTo({ url: LOGIN_PAGE });
  }
};
