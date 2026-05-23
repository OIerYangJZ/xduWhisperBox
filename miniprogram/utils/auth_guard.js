const LOGIN_PAGE = '/pages/profile/auth/index';

const TABBAR_PAGES = [
  '/pages/campus/index',
  '/pages/ai/index',
  '/pages/profile/conversations/index',
  '/pages/profile/index'
];

let isNavigating = false;

const withNavLock = (fn) => {
  if (isNavigating) return;
  isNavigating = true;
  fn();
  setTimeout(() => {
    isNavigating = false;
  }, 1000);
};

const isLoginRoute = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return false;
  const route = `/${current.route || ''}`;
  return route === LOGIN_PAGE || route === '/pages/profile/register/index';
};

const isCurrentPageTabbar = () => {
  const pages = getCurrentPages();
  const current = pages[pages.length - 1];
  if (!current) return false;
  const route = `/${current.route || ''}`;
  return TABBAR_PAGES.includes(route);
};

export const hasLogin = () => {
  return Boolean(wx.getStorageSync('token'));
};

export const requireLoginPage = () => {
  if (hasLogin()) return true;
  if (!isLoginRoute()) {
    withNavLock(() => {
      if (isCurrentPageTabbar()) {
        wx.navigateTo({ url: LOGIN_PAGE });
      } else {
        wx.redirectTo({ url: LOGIN_PAGE });
      }
    });
  }
  return false;
};

export const clearLoginAndRedirect = () => {
  wx.removeStorageSync('token');
  if (!isLoginRoute()) {
    withNavLock(() => {
      wx.reLaunch({ url: LOGIN_PAGE });
    });
  }
};
