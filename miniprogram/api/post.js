import request from '../utils/request';
import { getData, normalizePost, toArray } from '../utils/format';

const normalizeLegacyPost = (raw = {}) => {
  const post = normalizePost(raw);
  return {
    ...post,
    authorName: post.authorAlias,
    images: post.imageUrls,
    isLiked: post.liked,
    isFavorited: post.favorited
  };
};

const normalizeLegacyPostListResponse = (response) => {
  const payload = getData(response, {});
  const rows = Array.isArray(payload) ? payload : toArray(payload.items);
  return {
    ...response,
    data: {
      ...(Array.isArray(payload) ? {} : payload),
      items: rows.map(normalizeLegacyPost)
    }
  };
};

/**
 * 获取帖子列表
 * @param {Object} params - 分页或过滤参数，例如 { page: 1, limit: 10, channel: 'treehole' }
 */
export const getPosts = async (params = {}) => {
  const response = await request.get('/api/posts', params);
  return normalizeLegacyPostListResponse(response);
};

/**
 * 获取帖子详情
 * @param {string} postId - 帖子 ID
 */
export const getPostById = async (postId) => {
  const response = await request.get(`/api/posts/${postId}`);
  return {
    ...response,
    data: normalizeLegacyPost(getData(response, {}))
  };
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
