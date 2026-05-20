import request from '../utils/request';
import { DEFAULT_CHANNELS, getData, normalizeComment, normalizePost, toArray } from '../utils/format';

export const getChannels = async () => {
  try {
    const response = await request.get('/api/channels');
    const rows = toArray(getData(response, []))
      .map((item) => String(item && item.name ? item.name : item).trim())
      .filter(Boolean);
    return rows.length ? rows : DEFAULT_CHANNELS;
  } catch (error) {
    return DEFAULT_CHANNELS;
  }
};

export const getPosts = async (params = {}) => {
  const response = await request.get('/api/posts', params);
  const payload = getData(response, []);
  const rows = Array.isArray(payload) ? payload : toArray(payload.items);
  return rows.map(normalizePost);
};

export const getPost = async (postId) => {
  const response = await request.get(`/api/posts/${postId}`);
  return normalizePost(getData(response, {}));
};

export const getPostComments = async (postId, params = {}) => {
  const response = await request.get(`/api/posts/${postId}/comments`, params);
  return toArray(getData(response, [])).map(normalizeComment);
};

export const createPost = async (payload) => {
  const response = await request.post('/api/posts', payload);
  return normalizePost(getData(response, {}));
};

export const createComment = async (postId, payload) => {
  const response = await request.post(`/api/posts/${postId}/comments`, payload);
  return normalizeComment(getData(response, {}));
};

export const togglePostLike = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/like`, {});
  return getData(response, {});
};

export const toggleCommentLike = async (commentId) => {
  const response = await request.post(`/api/comments/${commentId}/like`, {});
  return getData(response, {});
};

export const favoritePost = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/favorite`, {});
  return getData(response, {});
};

export const unfavoritePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}/favorite`, {});
  return getData(response, {});
};

export const incrementPostView = async (postId) => {
  const response = await request.post(`/api/posts/${postId}/view`, {});
  return getData(response, {});
};

export const reportTarget = async (payload) => {
  const response = await request.post('/api/reports', payload);
  return getData(response, {});
};

export const getFavoritePosts = async () => {
  const response = await request.get('/api/posts/favorites');
  return toArray(getData(response, [])).map(normalizePost);
};

export const updatePost = async (postId, payload) => {
  const response = await request.patch(`/api/posts/${postId}`, payload);
  return normalizePost(getData(response, {}));
};

export const deletePost = async (postId) => {
  const response = await request.delete(`/api/posts/${postId}`, {});
  return getData(response, {});
};

export const deleteComment = async (commentId) => {
  const response = await request.delete(`/api/comments/${commentId}`, {});
  return getData(response, {});
};
