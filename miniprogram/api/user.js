import request from '../utils/request';
import { getData, normalizePost, resolveUrl, toArray } from '../utils/format';

export const updateNotificationPreferences = async (payload) => {
  const response = await request.patch('/api/users/notification-preferences', payload);
  return getData(response, {});
};

export const updateProfile = async (payload) => {
  const response = await request.patch('/api/users/me', payload);
  return getData(response, {});
};

export const updatePrivacy = async (payload) => {
  const response = await request.patch('/api/users/privacy', payload);
  return getData(response, {});
};

export const submitCancellationRequest = async (payload) => {
  const response = await request.post('/api/users/me/cancellation-request', payload);
  return getData(response, {});
};

export const submitLevelUpgradeRequest = async (payload) => {
  const response = await request.post('/api/users/me/level-upgrade-request', payload);
  return getData(response, {});
};

export const getMyPosts = async () => {
  const response = await request.get('/api/posts/mine');
  return toArray(getData(response, [])).map(normalizePost);
};

export const getMyComments = async () => {
  const response = await request.get('/api/comments/mine');
  return toArray(getData(response, []));
};

export const getMyReports = async () => {
  const response = await request.get('/api/reports/mine');
  return toArray(getData(response, []));
};

export const getReportDetail = async (reportId) => {
  const response = await request.get(`/api/reports/${reportId}`);
  return getData(response, {});
};

export const getPublicUser = async (userId) => {
  const response = await request.get(`/api/users/${userId}`);
  const data = getData(response, {});
  return {
    ...data,
    avatarUrl: resolveUrl(data.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(data.backgroundImageUrl || '')
  };
};

export const searchUsers = async (keyword) => {
  const response = await request.get('/api/users/search', { keyword });
  return toArray(getData(response, [])).map((item) => ({
    ...item,
    id: String(item.id || item.userId || ''),
    avatarUrl: resolveUrl(item.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(item.backgroundImageUrl || '')
  }));
};

export const followUser = async (userId) => {
  const response = await request.post(`/api/users/${userId}/follow`, {});
  return getData(response, {});
};

export const unfollowUser = async (userId) => {
  const response = await request.post(`/api/users/${userId}/unfollow`, {});
  return getData(response, {});
};

export const getFollowing = async () => {
  const response = await request.get('/api/users/me/following');
  return toArray(getData(response, []));
};

export const getFollowers = async () => {
  const response = await request.get('/api/users/me/followers');
  return toArray(getData(response, []));
};

export const getFriends = async () => {
  const response = await request.get('/api/users/me/friends');
  return toArray(getData(response, []));
};

export const submitFeedback = async (payload) => {
  const response = await request.post('/api/feedback', payload);
  return getData(response, {});
};
