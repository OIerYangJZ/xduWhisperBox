// 环境配置
// auto: 电脑微信开发者工具使用本机 localhost；真机使用当前电脑局域网 IP
// devtools: 只在电脑微信开发者工具中使用本机后端
// lan: 真机调试本地后端，手机和电脑必须在同一局域网
// prod: 线上 HTTPS 域名，需配置到小程序后台 request 合法域名
const loadLocalConfig = () => {
  try {
    if (typeof require !== 'function') {
      return {};
    }
    const localModule = require('./env.local');
    return localModule.default || localModule.localConfig || localModule || {};
  } catch (error) {
    const message = String((error && error.message) || '');
    if (/env\.local/.test(message) && /Cannot find module|not found|not defined|找不到|不存在/.test(message)) {
      return {};
    }
    throw error;
  }
};

const LOCAL_CONFIG = loadLocalConfig();
const ENV = LOCAL_CONFIG.env || 'auto'; // 'auto' | 'devtools' | 'lan' | 'prod'

const CONFIG = {
  devtools: {
    name: 'devtools',
    // 仅电脑开发者工具可用；真机中的 localhost 指向手机自身。
    baseUrl: LOCAL_CONFIG.devtoolsBaseUrl || 'http://localhost:8080',
  },
  lan: {
    name: 'lan',
    // start_backend.bat / scripts/start_backend.sh 会按当前电脑 WLAN IP 生成 env.local.js。
    baseUrl: LOCAL_CONFIG.lanBaseUrl,
  },
  prod: {
    name: 'prod',
    // 生产环境域名（需要配置在小程序后台的 request 合法域名中）
    baseUrl: 'https://www.seediantreehole.cn',
  }
};

const getRuntimePlatform = () => {
  try {
    if (typeof wx !== 'undefined' && wx.getDeviceInfo) {
      return String(wx.getDeviceInfo().platform || '').toLowerCase();
    }
    if (typeof wx !== 'undefined' && wx.getSystemInfoSync) {
      const info = wx.getSystemInfoSync();
      return String(info.platform || '').toLowerCase();
    }
  } catch (error) {}
  return '';
};

const isDevtoolsRuntime = () => {
  const platform = getRuntimePlatform();
  return platform === 'devtools';
};

const resolveConfig = () => {
  let config;
  if (ENV === 'auto') {
    config = isDevtoolsRuntime() ? CONFIG.devtools : CONFIG.lan;
  } else {
    config = CONFIG[ENV];
  }
  if (!config) {
    throw new Error(`未知小程序环境：${ENV}`);
  }
  if (!config.baseUrl) {
    throw new Error('小程序本地后端地址未配置：请先运行 start_backend.bat 生成 miniprogram/config/env.local.js');
  }
  return config;
};

export const envConfig = resolveConfig();
export const baseUrl = envConfig.baseUrl;
export const envName = ENV === 'auto' ? `auto:${envConfig.name}` : ENV;
