import { deleteConversation, getConversations } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    loading: true,
    conversations: []
  },

  onShow() {
    if (!requireLoginPage()) return;
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const conversations = await getConversations();
      this.setData({ conversations, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openChat(event) {
    const item = this.data.conversations[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    wx.navigateTo({
      url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&blockedByMe=${item.blockedByMe ? '1' : '0'}`
    });
  },

  goRequests() {
    wx.navigateTo({ url: '/pages/profile/message-requests/index' });
  },

  removeConversation(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    wx.showModal({
      title: '删除会话',
      content: '确认删除这条会话记录？',
      confirmText: '删除',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await deleteConversation(item.id);
          const conversations = this.data.conversations.slice();
          conversations.splice(index, 1);
          this.setData({ conversations });
        } catch (error) {}
      }
    });
  }
});
