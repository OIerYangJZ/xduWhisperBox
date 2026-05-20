import request from '../utils/request';

/**
 * 获取校园公告/新闻
 */
export const getAnnouncements = () => {
  return request.get('/api/announcements');
};

/**
 * 获取学院列表
 */
export const getColleges = () => {
  return request.get('/api/colleges');
};
