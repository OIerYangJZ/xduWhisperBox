import request from '../utils/request';

/**
 * 账号密码登录
 * @param {string} identifier - 学号或邮箱
 * @param {string} password - 密码
 */
export const login = (identifier, password) => {
  return request.post('/api/auth/login', { identifier, password });
};

/**
 * 注册
 */
export const register = (data) => {
  return request.post('/api/auth/register', data);
};

/**
 * 邮箱验证码验证
 */
export const verifyEmail = (email, code, password = '') => {
  return request.post('/api/auth/verify', { email, code, password });
};

/**
 * 获取当前用户信息（包含认证状态）
 */
export const getUserInfo = () => {
  return request.get('/api/users/me');
};

/**
 * 发送验证码
 */
export const sendCode = (email) => {
  return request.post('/api/auth/send-code', { email });
};

/**
 * 退出登录
 */
export const logout = () => {
  return request.post('/api/auth/logout');
};
