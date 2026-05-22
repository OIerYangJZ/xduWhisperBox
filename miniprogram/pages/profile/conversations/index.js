import { deleteConversation, fetchDmRequests, getConversations } from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const REVEAL_WIDTH_RPX = 128;

Page({
  data: {
    loading: true,
    conversations: [],
    requestCount: 0
  },

  onShow() {
    if (!requireLoginPage()) return;
    applyThemeAndLanguage(this);
    this.loadData();
  },

  onPullDownRefresh() {
    this.loadData().finally(() => wx.stopPullDownRefresh());
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const [conversations, requests] = await Promise.all([
        getConversations(),
        fetchDmRequests()
      ]);
      const normalized = conversations.map(item => ({
        ...item,
        offsetX: 0
      }));
      const requestCount = requests.filter(item => item.status === 'pending').length;
      this.setData({ conversations: normalized, requestCount, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  openChat(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    if ((item.offsetX || 0) < 0) {
      this.resetSwipe(index);
      return;
    }
    wx.navigateTo({
      url: `/pages/profile/chat/index?id=${item.id}&name=${encodeURIComponent(item.name || '私信')}&peerUserId=${encodeURIComponent(item.peerUserId || '')}&peerAvatar=${encodeURIComponent(item.avatarUrl || '')}&blockedByMe=${item.blockedByMe ? '1' : '0'}`
    });
  },

  openProfile(event) {
    const id = event.currentTarget.dataset.id || '';
    if (!id) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${id}` });
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
  },

  onRowTouchStart(event) {
    const index = Number(event.currentTarget.dataset.index);
    const item = this.data.conversations[index];
    if (!item) return;
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    this._touchIndex = index;
    this._touchStartX = touch.clientX;
    this._touchStartY = touch.clientY;
    this._touchStartOffset = item.offsetX || 0;
  },

  onRowTouchMove(event) {
    if (this._touchIndex === undefined || this._touchIndex === null) return;
    const touch = event.touches && event.touches[0];
    if (!touch) return;
    const dx = touch.clientX - this._touchStartX;
    const dy = touch.clientY - this._touchStartY;
    if (Math.abs(dy) > Math.abs(dx)) return;
    const rpxPerPx = this.getRpxPerPx();
    const dxRpx = dx * rpxPerPx;
    const nextOffset = Math.min(0, Math.max(this._touchStartOffset + dxRpx, -REVEAL_WIDTH_RPX));
    this.setConversationOffset(this._touchIndex, nextOffset);
    if (Math.abs(dx) > 6) {
      this._rowMoved = true;
    }
  },

  onRowTouchEnd() {
    if (this._touchIndex === undefined || this._touchIndex === null) return;
    const index = this._touchIndex;
    const item = this.data.conversations[index];
    const offsetX = item ? (item.offsetX || 0) : 0;
    const nextOffset = offsetX < -REVEAL_WIDTH_RPX / 2 ? -REVEAL_WIDTH_RPX : 0;
    this.setConversationOffset(index, nextOffset);
    this._touchIndex = null;
    this._touchStartX = 0;
    this._touchStartY = 0;
    this._touchStartOffset = 0;
  },

  resetSwipe(index) {
    this.setConversationOffset(index, 0);
  },

  setConversationOffset(index, offsetX) {
    const conversations = this.data.conversations.slice();
    const item = conversations[index];
    if (!item) return;
    item.offsetX = offsetX;
    conversations[index] = item;
    this.setData({ conversations });
  },

  getRpxPerPx() {
    if (this._rpxPerPx) return this._rpxPerPx;
    const info = wx.getWindowInfo();
    this._rpxPerPx = 750 / info.windowWidth;
    return this._rpxPerPx;
  }
});
