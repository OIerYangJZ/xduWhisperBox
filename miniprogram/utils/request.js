import { baseUrl } from '../config/env';

/**
 * 封装微信的 wx.request
 */
const request = (options) => {
  return new Promise((resolve, reject) => {
    // 获取本地存储的 token
    const token = wx.getStorageSync('token');

    // 默认 header
    const header = {
      'Content-Type': 'application/json',
      'X-Client-Type': 'wechat-miniprogram', // 标识来源，方便后端识别
      ...options.header
    };

    if (token) {
      header['Authorization'] = `Bearer ${token}`;
    }

    wx.request({
      url: options.url.startsWith('http') ? options.url : baseUrl + options.url,
      method: options.method || 'GET',
      data: options.data || {},
      header: header,
      timeout: 10000,
      success: (res) => {
        const { statusCode, data } = res;
        
        // HTTP 状态码 2xx 表示成功
        if (statusCode >= 200 && statusCode < 300) {
          resolve(data);
        } else if (statusCode === 401) {
          // 未登录或 token 过期
          wx.removeStorageSync('token');
          wx.showToast({
            title: '登录已过期，请重新登录',
            icon: 'none'
          });
          // 可以在这里做自动跳转登录页的逻辑
          // wx.navigateTo({ url: '/pages/profile/auth/index' });
          reject(res);
        } else {
          // 其他服务器错误
          wx.showToast({
            title: data.message || '网络请求错误',
            icon: 'none'
          });
          reject(res);
        }
      },
      fail: (err) => {
        wx.showToast({
          title: '网络异常，请检查网络',
          icon: 'none'
        });
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

export default request;
