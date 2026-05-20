import request from '../utils/request';
import { getData, resolveUrl, toArray } from '../utils/format';

const adminOptions = { tokenKey: 'adminToken' };

export const adminLogin = async (username, password) => {
  const response = await request.post('/api/admin/auth/login', { username, password }, adminOptions);
  return getData(response, {});
};

export const adminLogout = async () => {
  const response = await request.post('/api/admin/auth/logout', {}, adminOptions);
  return getData(response, {});
};

export const getAdminMe = async () => {
  const response = await request.get('/api/admin/auth/me', {}, adminOptions);
  return getData(response, {});
};

export const getAdminOverview = async () => {
  const response = await request.get('/api/admin/overview', {}, adminOptions);
  return getData(response, {});
};

export const getAdminReviews = async (params = {}) => {
  const response = await request.get('/api/admin/reviews', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminReview = async (targetType, targetId, action) => {
  const response = await request.post(`/api/admin/reviews/${targetType}/${targetId}/${action}`, {}, adminOptions);
  return getData(response, {});
};

export const handleAdminReviewBatch = async (items) => {
  const response = await request.post('/api/admin/reviews/batch', { items }, adminOptions);
  return getData(response, {});
};

export const getAdminReports = async (params = {}) => {
  const response = await request.get('/api/admin/reports', params, adminOptions);
  return toArray(getData(response, []));
};

export const handleAdminReport = async (reportId, action, result = '') => {
  const response = await request.post(`/api/admin/reports/${reportId}/handle`, { action, result }, adminOptions);
  return getData(response, {});
};

export const getAdminImageReviews = async (params = {}) => {
  const response = await request.get('/api/admin/images/reviews', params, adminOptions);
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    url: resolveUrl(item.url || item.imageUrl || '')
  }));
};

export const handleAdminImageReview = async (uploadId, action, note = '') => {
  const response = await request.post(`/api/admin/images/${uploadId}/review`, { action, note }, adminOptions);
  return getData(response, {});
};
