import { getNotifications, markAllNotificationsRead, markNotificationRead } from '../../../api/notifications';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    loading: true,
    items: [],
    unreadCount: 0
  },

  onShow() {
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    if (!requireLoginPage()) return;
    this.setData({ loading: true });
    try {
      const data = await getNotifications();
      this.setData({ items: data.items, unreadCount: data.unreadCount, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  async markAllRead() {
    try {
      await markAllNotificationsRead();
      const items = this.data.items.map((item) => ({ ...item, isRead: true }));
      this.setData({ items, unreadCount: 0 });
    } catch (error) {}
  },

  async openItem(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.items[index];
    if (!item) return;
    if (!item.isRead) {
      markNotificationRead(item.id).catch(() => {});
      const items = this.data.items.slice();
      items[index] = { ...item, isRead: true };
      this.setData({ items, unreadCount: Math.max(0, this.data.unreadCount - 1) });
    }
    const postId = item.postId || (item.relatedType === 'post' ? item.relatedId : '');
    const commentId = item.commentId || (item.relatedType === 'comment' ? item.relatedId : '');
    if (postId) {
      wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}` });
      return;
    }
    if (item.relatedType === 'announcement' || item.type === 'system_announcement') {
      wx.navigateTo({
        url: `/pages/campus/announcement-detail/index?title=${encodeURIComponent(item.title || '')}&content=${encodeURIComponent(item.content || '')}&createdAt=${encodeURIComponent(item.createdAt || '')}`
      });
      return;
    }
    if (item.relatedType === 'conversation' || item.type === 'message') {
      wx.switchTab({ url: '/pages/profile/conversations/index' });
      return;
    }
    if (item.relatedType === 'user') {
      wx.navigateTo({ url: `/pages/profile/public-user/index?id=${item.relatedId}` });
    }
  }
});
