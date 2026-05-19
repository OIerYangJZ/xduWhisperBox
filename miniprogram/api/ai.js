import request from '../utils/request';

/**
 * AI 问答 API
 */
export const sendAiMessage = (content) => {
  return request.post('/api/ai/chat', { content });
};
