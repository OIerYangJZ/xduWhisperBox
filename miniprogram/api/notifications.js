import request from '../utils/request';
import { getData, normalizeNotification, toArray } from '../utils/format';

export const getNotifications = async () => {
  const response = await request.get('/api/notifications');
  const data = getData(response, {});
  return {
    items: toArray(data.items).map(normalizeNotification),
    unreadCount: Number(data.unreadCount || 0)
  };
};

export const markAllNotificationsRead = async () => {
  const response = await request.post('/api/notifications/read-all', {});
  return getData(response, {});
};

export const markNotificationRead = async (notificationId) => {
  const response = await request.get(`/api/notifications/${notificationId}/read`);
  return normalizeNotification(getData(response, {}));
};
