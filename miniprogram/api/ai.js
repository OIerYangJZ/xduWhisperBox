import { request } from '../../utils/request';

/**
 * 模拟的 AI 问答 API (待后端真实接入)
 */
export const sendAiMessage = (message) => {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        data: {
          reply: `这是关于“${message}”的自动回复，由于后端 AI RAG 尚未完全联调，此处为占位数据。`
        }
      });
    }, 1000);
  });
};
