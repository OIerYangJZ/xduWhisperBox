// 环境配置
// auto: 电脑微信开发者工具使用本机 localhost；真机使用当前电脑局域网 IP
// devtools: 只在电脑微信开发者工具中使用本机后端
// lan: 真机调试本地后端，手机和电脑必须在同一局域网
// prod: 线上 HTTPS 域名，需配置到小程序后台 request 合法域名
const ENV = 'auto'; // 'auto' | 'devtools' | 'lan' | 'prod'

const CONFIG = {
  devtools: {
    name: 'devtools',
    // 仅电脑开发者工具可用；真机中的 localhost 指向手机自身。
    baseUrl: 'http://localhost:8080',
  },
  lan: {
    name: 'lan',
    // 当前电脑 en0 局域网 IP。若 Wi-Fi 变化，请用 ifconfig 查看后替换。
    baseUrl: 'http://192.168.0.101:8080',
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
  return platform === 'devtools' || platform.indexOf('mac') >= 0 || platform.indexOf('windows') >= 0;
};

const resolveConfig = () => {
  if (ENV === 'auto') {
    return isDevtoolsRuntime() ? CONFIG.devtools : CONFIG.lan;
  }
  return CONFIG[ENV] || CONFIG.devtools;
};

export const envConfig = resolveConfig();
export const baseUrl = envConfig.baseUrl;
export const envName = ENV === 'auto' ? `auto:${envConfig.name}` : ENV;
