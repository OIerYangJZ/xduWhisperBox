import request from '../utils/request';

/**
 * 获取校园公告/新闻
 */
export const getAnnouncements = () => {
  return request.get('/api/announcements');
};

/**
 * 获取学院列表 (暂时 Mock 数据，后续可由后端动态返回)
 */
export const getColleges = () => {
  return new Promise((resolve) => {
    resolve({
      data: [
        { id: 'cs', name: '计算机科学与技术学院', icon: '💻' },
        { id: 'ee', name: '电子工程学院', icon: '📡' },
        { id: 'is', name: '信息安全学院', icon: '🔒' },
        { id: 'me', name: '机电工程学院', icon: '⚙️' },
        { id: 'math', name: '数学与统计学院', icon: '📐' },
        { id: 'phys', name: '物理学院', icon: '⚛️' },
        { id: 'human', name: '人文学院', icon: '📖' },
        { id: 'econ', name: '经济与管理学院', icon: '📊' }
      ]
    });
  });
};
