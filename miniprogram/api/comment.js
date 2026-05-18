import request from '../utils/request';

/**
 * 获取帖子的评论列表
 * @param {string} postId 
 * @param {Object} params - { page, limit }
 */
export const getComments = (postId, params = {}) => {
  return request.get(`/api/posts/${postId}/comments`, params);
};

/**
 * 发表评论
 * @param {string} postId 
 * @param {Object} data - { content, isAnonymous, replyToId }
 */
export const createComment = (postId, data) => {
  return request.post(`/api/posts/${postId}/comments`, data);
};

/**
 * 点赞评论
 * @param {string} commentId 
 * @param {boolean} isLike 
 */
export const likeComment = (commentId, isLike = true) => {
  return request.post(`/api/comments/${commentId}/like`, { like: isLike });
};
