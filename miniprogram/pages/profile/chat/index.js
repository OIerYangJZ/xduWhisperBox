import {
  createDmRequest,
  recallMessage as recallConversationMessage,
  getConversationMessages,
  sendConversationMessage,
  unblockConversationPeer,
  blockConversationPeer
} from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    conversationId: '',
    peerUserId: '',
    messages: [],
    content: '',
    loading: true,
    sending: false,
    blockedByMe: false,
    replyToId: '',
    replyToContent: '',
    replyToSender: '',
    selectedMessage: null
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const conversationId = options.id || '';
    if (options.name) wx.setNavigationBarTitle({ title: decodeURIComponent(options.name) });
    this.setData({
      conversationId,
      peerUserId: options.peerUserId || '',
      blockedByMe: options.blockedByMe === '1'
    });
    if (conversationId) this.loadMessages();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadMessages() {
    this.setData({ loading: true });
    try {
      const messages = await getConversationMessages(this.data.conversationId);
      this.setData({ messages, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  onInput(event) {
    this.setData({ content: event.detail.value });
  },

  onMessageLongPress(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message) return;
    const items = ['回复', '复制', '详情'];
    if (message.fromMe && !message.deleted && !message.recalled) items.push('撤回');
    items.push('转发');
    wx.showActionSheet({
      itemList: items,
      success: async (res) => {
        const action = items[res.tapIndex];
        if (action === '回复') {
          this.setData({
            replyToId: message.id,
            replyToContent: message.content || '',
            replyToSender: message.senderName || '对方'
          });
        }
        if (action === '复制') {
          wx.setClipboardData({ data: message.content || '' });
        }
        if (action === '详情') {
          this.setData({ selectedMessage: message });
          wx.showModal({
            title: '消息详情',
            content: `发送时间：${message.createdAt || ''}\n状态：${message.recalled ? '已撤回' : '正常'}`,
            showCancel: false
          });
        }
        if (action === '撤回') {
          await this.recallMessage(message.id);
        }
        if (action === '转发') {
          const targetUserId = this.data.peerUserId || message.targetUserId || '';
          if (targetUserId) {
            await createDmRequest({ targetUserId, reason: `转发消息：${message.content || ''}` });
            wx.showToast({ title: '已转发请求', icon: 'success' });
          }
        }
      }
    });
  },

  clearReply() {
    this.setData({ replyToId: '', replyToContent: '', replyToSender: '' });
  },

  async sendMessage() {
    const content = this.data.content.trim();
    if (!content || this.data.sending) return;
    this.setData({ sending: true });
    try {
      await sendConversationMessage(this.data.conversationId, {
        content,
        replyToId: this.data.replyToId || ''
      });
      this.setData({ content: '', replyToId: '', replyToContent: '', replyToSender: '' });
      await this.loadMessages();
    } catch (error) {}
    this.setData({ sending: false });
  },

  async recallMessage(messageId) {
    try {
      await recallConversationMessage(this.data.conversationId, messageId);
      await this.loadMessages();
      wx.showToast({ title: '已撤回', icon: 'success' });
    } catch (error) {}
  },

  async toggleBlock() {
    try {
      if (this.data.blockedByMe) {
        await unblockConversationPeer(this.data.conversationId);
      } else {
        await blockConversationPeer(this.data.conversationId);
      }
      this.setData({ blockedByMe: !this.data.blockedByMe });
    } catch (error) {}
  }
});
