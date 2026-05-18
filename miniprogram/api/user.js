import request from '../utils/request';
import { getData } from '../utils/format';

export const updateNotificationPreferences = async (payload) => {
  const response = await request.patch('/api/users/notification-preferences', payload);
  return getData(response, {});
};

export const updateProfile = async (payload) => {
  const response = await request.patch('/api/users/me', payload);
  return getData(response, {});
};
