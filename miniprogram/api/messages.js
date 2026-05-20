import request from '../utils/request';
import { getData, toArray } from '../utils/format';

export const getConversations = async () => {
  const response = await request.get('/api/messages/conversations');
  return toArray(getData(response, []));
};

export const fetchDmRequests = async () => {
  const response = await request.get('/api/messages/requests');
  return toArray(getData(response, []));
};

export const handleDmRequest = async (requestId, accept) => {
  const action = accept ? 'accept' : 'reject';
  const response = await request.post(`/api/messages/requests/${requestId}/${action}`, {});
  return getData(response, {});
};

export const createDmRequest = async (payload) => {
  const response = await request.post('/api/messages/requests', payload);
  return getData(response, {});
};

export const getConversationMessages = async (conversationId) => {
  const response = await request.get(`/api/messages/conversations/${conversationId}/messages`);
  return toArray(getData(response, []));
};

export const createDirectConversation = async (payload) => {
  const response = await request.post('/api/messages/conversations/direct', payload);
  return getData(response, {});
};

export const sendConversationMessage = async (conversationId, payload) => {
  const response = await request.post(`/api/messages/conversations/${conversationId}/messages`, payload);
  return getData(response, {});
};

export const recallMessage = async (conversationId, messageId) => {
  const response = await request.delete(`/api/messages/messages/${messageId}/recall?conversationId=${encodeURIComponent(conversationId)}`, {});
  return getData(response, {});
};

export const deleteConversation = async (conversationId) => {
  const response = await request.delete(`/api/messages/conversations/${conversationId}`, {});
  return getData(response, {});
};

export const blockConversationPeer = async (conversationId) => {
  const response = await request.post(`/api/messages/conversations/${conversationId}/block`, {});
  return getData(response, {});
};

export const unblockConversationPeer = async (conversationId) => {
  const response = await request.post(`/api/messages/conversations/${conversationId}/unblock`, {});
  return getData(response, {});
};
