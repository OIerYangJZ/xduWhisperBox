import request from '../utils/request';

/**
 * 获取帖子列表
 * @param {Object} params - 分页或过滤参数，例如 { page: 1, limit: 10, channel: 'treehole' }
 */
export const getPosts = (params = {}) => {
  return request.get('/api/posts', params);
};

/**
 * 获取帖子详情
 * @param {string} postId - 帖子 ID
 */
export const getPostById = (postId) => {
  return request.get(`/api/posts/${postId}`);
};

/**
 * 点赞帖子
 * @param {string} postId - 帖子 ID
 * @param {boolean} isLike - true 为点赞，false 为取消点赞
 */
export const likePost = (postId, isLike = true) => {
  return request.post(`/api/posts/${postId}/like`, { like: isLike });
};

/**
 * 发布帖子
 * @param {Object} data - 帖子数据 { content, channel, tags, imageIds, isAnonymous }
 */
export const createPost = (data) => {
  return request.post('/api/posts', data);
};
