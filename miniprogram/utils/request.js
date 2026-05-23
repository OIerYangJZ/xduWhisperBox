import { baseUrl, envName } from '../config/env';
import { clearLoginAndRedirect } from './auth_guard';

// 防止多个并发请求失败时弹出多个 Toast
let _lastToastTime = 0;
const showToastOnce = (title, icon = 'none') => {
  const now = Date.now();
  if (now - _lastToastTime < 2000) return;
  _lastToastTime = now;
  wx.showToast({ title, icon });
};

const buildUrl = (url) => {
  if (url.startsWith('http')) return url;
  return `${baseUrl.replace(/\/$/, '')}${url}`;
};

const networkErrorMessage = () => {
  if (/localhost|127\.0\.0\.1/i.test(baseUrl)) {
    return '真机无法访问 localhost，请改用电脑局域网 IP';
  }
  if (envName === 'lan' || envName === 'auto:lan') {
    return '请确认手机和电脑在同一 Wi-Fi，且电脑防火墙允许 8080 端口';
  }
  return '网络异常，请检查域名和 HTTPS 配置';
};

/**
 * 封装微信的 wx.request
 */
const request = (options) => {
  return new Promise((resolve, reject) => {
    const token = wx.getStorageSync('token');
    const requestUrl = options.url || '';
    const publicAuthPaths = [
      '/api/auth/login',
      '/api/auth/register',
      '/api/auth/verify',
      '/api/auth/send-code',
      '/api/auth/resend-code',
      '/api/auth/password/send-code',
      '/api/auth/password/reset'
    ];
    const isPublicAuthPath = publicAuthPaths.some((path) => requestUrl === path);

    if (!token && !isPublicAuthPath) {
      clearLoginAndRedirect();
      reject({ statusCode: 401, data: { message: '请先登录' } });
      return;
    }

    // 默认 header
    const header = {
      'Content-Type': 'application/json',
      'X-Client-Type': 'wechat-miniprogram', // 标识来源，方便后端识别
      ...options.header
    };

    if (token && !isPublicAuthPath) {
      header['Authorization'] = `Bearer ${token}`;
    }

    const url = buildUrl(options.url);

    wx.request({
      url,
      method: options.method || 'GET',
      data: options.data || {},
      header: header,
      timeout: options.timeout || 15000,
      success: (res) => {
        const { statusCode, data } = res;
        
        // HTTP 状态码 2xx 表示成功
        if (statusCode >= 200 && statusCode < 300) {
          resolve(data);
        } else if (statusCode === 401 && token) {
          // 未登录或 token 过期
          clearLoginAndRedirect();
          wx.showToast({
            title: '登录已过期，请重新登录',
            icon: 'none'
          });
          reject(res);
        } else {
          // 其他服务器错误
          console.error('[request http error]', url, res);
          showToastOnce((data && data.message) || networkErrorMessage());
          reject(res);
        }
      },
      fail: (err) => {
        console.error('[request failed]', url, err);
        showToastOnce(networkErrorMessage());
        reject(err);
      }
    });
  });
};

// 提供快捷方法
request.get = (url, data, options = {}) => {
  return request({ url, method: 'GET', data, ...options });
};

request.post = (url, data, options = {}) => {
  return request({ url, method: 'POST', data, ...options });
};

request.put = (url, data, options = {}) => {
  return request({ url, method: 'PUT', data, ...options });
};

request.delete = (url, data, options = {}) => {
  return request({ url, method: 'DELETE', data, ...options });
};

request.patch = (url, data, options = {}) => {
  return request({ url, method: 'PATCH', data, ...options });
};

export default request;
