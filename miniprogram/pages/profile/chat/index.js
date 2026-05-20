import {
  blockConversationPeer,
  getConversationMessages,
  sendConversationMessage,
  unblockConversationPeer
} from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    conversationId: '',
    messages: [],
    content: '',
    loading: true,
    sending: false,
    blockedByMe: false
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const conversationId = options.id || '';
    if (options.name) wx.setNavigationBarTitle({ title: decodeURIComponent(options.name) });
    this.setData({
      conversationId,
      blockedByMe: options.blockedByMe === '1'
    });
    if (conversationId) this.loadMessages();
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

  async sendMessage() {
    const content = this.data.content.trim();
    if (!content || this.data.sending) return;
    this.setData({ sending: true });
    try {
      await sendConversationMessage(this.data.conversationId, { content });
      this.setData({ content: '' });
      await this.loadMessages();
    } catch (error) {}
    this.setData({ sending: false });
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
