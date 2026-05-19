import request from '../utils/request';
import { getData, normalizeComment, toArray } from '../utils/format';

const normalizeLegacyComment = (raw = {}) => {
  const comment = normalizeComment(raw);
  return {
    ...comment,
    authorName: comment.authorAlias,
    isLiked: comment.liked
  };
};

const normalizeLegacyCommentListResponse = (response) => {
  const payload = getData(response, {});
  const rows = Array.isArray(payload) ? payload : toArray(payload.items);
  return {
    ...response,
    data: {
      ...(Array.isArray(payload) ? {} : payload),
      items: rows.map(normalizeLegacyComment)
    }
  };
};

/**
 * 获取帖子的评论列表
 * @param {string} postId 
 * @param {Object} params - { page, limit }
 */
export const getComments = async (postId, params = {}) => {
  const response = await request.get(`/api/posts/${postId}/comments`, params);
  return normalizeLegacyCommentListResponse(response);
};

/**
 * 发表评论
 * @param {string} postId 
 * @param {Object} data - { content, isAnonymous, replyToId }
 */
export const createComment = async (postId, data) => {
  const response = await request.post(`/api/posts/${postId}/comments`, data);
  return {
    ...response,
    data: normalizeLegacyComment(getData(response, {}))
  };
};

/**
 * 点赞评论
 * @param {string} commentId 
 * @param {boolean} isLike 
 */
export const likeComment = (commentId, isLike = true) => {
  return request.post(`/api/comments/${commentId}/like`, { like: isLike });
};
