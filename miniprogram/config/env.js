// 环境配置
const ENV = 'dev'; // 'dev' | 'prod'

const CONFIG = {
  dev: {
    // 本地开发请将此处的 IP 替换为你电脑的局域网 IP (例如 192.168.1.100) 以便真机调试
    // 如果只在开发者工具中测试，可以使用 127.0.0.1
    baseUrl: 'http://localhost:8080',
  },
  prod: {
    // 生产环境域名（需要配置在小程序后台的合法域名中）
    baseUrl: 'https://api.seediantreehole.cn',
  }
};

export const envConfig = CONFIG[ENV];
export const baseUrl = envConfig.baseUrl;
