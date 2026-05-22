import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const AI_CONFIG_STORAGE_KEY = 'aiProviderConfig';

export const DEFAULT_AI_CONFIG = {
  apiKey: '',
  baseUrl: '',
  model: '',
  models: [],
  knowledgeBase: '',
  includePosts: true
};

export const getAiConfig = () => ({
  ...DEFAULT_AI_CONFIG,
  ...(wx.getStorageSync(AI_CONFIG_STORAGE_KEY) || {})
});

export const saveAiConfig = (config) => {
  const next = {
    ...getAiConfig(),
    ...(config || {})
  };
  wx.setStorageSync(AI_CONFIG_STORAGE_KEY, next);
  return next;
};

export const clearAiConfig = () => {
  wx.removeStorageSync(AI_CONFIG_STORAGE_KEY);
};

export const fetchAiModels = async ({ apiKey, baseUrl }) => {
  const response = await request.post('/api/ai/models', { apiKey, baseUrl }, { timeout: 25000 });
  const data = getData(response, {});
  return toArray(data.models).map((item) => String(item || '').trim()).filter(Boolean);
};

export const sendAiMessage = (content, options = {}) => {
  const config = getAiConfig();
  return request.post('/api/ai/chat', {
    content,
    apiKey: config.apiKey,
    baseUrl: config.baseUrl,
    model: config.model,
    knowledgeBase: config.knowledgeBase,
    includePosts: config.includePosts !== false,
    messages: options.messages || []
  }, { timeout: 60000 });
};
