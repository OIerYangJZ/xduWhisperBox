// 环境配置
// devtools: 只在电脑微信开发者工具中使用本机后端
// lan: 真机调试本地后端，手机和电脑必须在同一局域网
// prod: 线上 HTTPS 域名，需配置到小程序后台 request 合法域名
const ENV = 'lan'; // 'devtools' | 'lan' | 'prod'

const CONFIG = {
  devtools: {
    // 仅电脑开发者工具可用；真机中的 localhost 指向手机自身。
    baseUrl: 'http://localhost:8080',
  },
  lan: {
    // 当前电脑 en0 局域网 IP。若 Wi-Fi 变化，请用 ifconfig 查看后替换。
    baseUrl: 'http://192.168.0.100:8080',
  },
  prod: {
    // 生产环境域名（需要配置在小程序后台的 request 合法域名中）
    baseUrl: 'https://www.seediantreehole.cn',
  }
};

export const envConfig = CONFIG[ENV];
export const baseUrl = envConfig.baseUrl;
export const envName = ENV;
