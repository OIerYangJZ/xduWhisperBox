import { getUserInfo } from '../../../api/auth';
import {
  blockConversationPeer,
  getConversations,
  getConversationMessages,
  recallMessage as recallConversationMessage,
  sendConversationMessage,
  unblockConversationPeer
} from '../../../api/messages';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const RECALL_WINDOW_SECONDS = 120;

Page({
  data: {
    conversationId: '',
    peerUserId: '',
    peerAvatar: '',
    peerName: '',
    myUserId: '',
    myAvatar: '',
    messages: [],
    messageItems: [],
    content: '',
    loading: true,
    sending: false,
    blockedByMe: false,
    replyToId: '',
    replyToContent: '',
    replyToSender: '',
    selectedMessageIds: [],
    selectMode: false,
    firstMessageWarningDismissed: false,
    showForwardPicker: false,
    forwardTargets: []
  },

  onLoad(options) {
    if (!requireLoginPage()) return;
    const conversationId = options.id || '';
    const peerName = options.name ? decodeURIComponent(options.name) : '私信';
    const peerAvatar = options.peerAvatar ? decodeURIComponent(options.peerAvatar) : '';
    const peerUserId = options.peerUserId || '';
    const blockedByMe = options.blockedByMe === '1';
    wx.setNavigationBarTitle({ title: peerName });
    this.setData({
      conversationId,
      peerUserId,
      peerAvatar,
      peerName,
      blockedByMe
    });
    this.loadCurrentUser();
    if (conversationId) this.loadMessages();
  },

  onShow() {
    applyThemeAndLanguage(this);
  },

  async loadCurrentUser() {
    try {
      const response = await getUserInfo();
      const user = response && response.data ? response.data : null;
      if (!user) return;
      this.setData({
        myUserId: user.userId || '',
        myAvatar: user.avatarUrl || ''
      });
    } catch (error) {}
  },

  async loadMessages() {
    this.setData({ loading: true });
    try {
      const messages = await getConversationMessages(this.data.conversationId);
      this.setData({
        messages,
        messageItems: this.buildMessageItems(messages),
        loading: false
      });
      this.scrollToBottom();
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  buildMessageItems(messages) {
    const items = [];
    let lastTime = null;
    messages.forEach((message, index) => {
      const messageTime = this.parseMessageTime(message.createdAt);
      if (lastTime === null || messageTime - lastTime > 5 * 60 * 1000) {
        items.push({
          type: 'time',
          id: `time-${message.id}`,
          label: this.formatTimeLabel(messageTime)
        });
        lastTime = messageTime;
      }
      const decorated = this.decorateMessage(message);
      decorated.index = index;
      items.push({
        type: 'message',
        id: message.id,
        index,
        message: decorated
      });
    });
    return items;
  },

  decorateMessage(message) {
    const createdAt = message.createdAt || '';
    const isRecalled = Boolean(message.recalled || message.deliveryStatus === 'recalled');
    const deliveryStatus = message.deliveryStatus || (isRecalled ? 'recalled' : 'sent');
    return {
      ...message,
      deliveryStatus,
      isRecalled,
      hasReplyContent: Boolean(message.hasReply || message.replyToContent),
      canRecall: this.canRecallMessage(message),
      displayTime: message.timeText || this.formatShortTime(createdAt),
      selected: this.data.selectedMessageIds.includes(message.id)
    };
  },

  parseMessageTime(value) {
    const parsed = Date.parse(value || '');
    return Number.isNaN(parsed) ? Date.now() : parsed;
  },

  formatShortTime(value) {
    const time = new Date(this.parseMessageTime(value));
    const hh = String(time.getHours()).padStart(2, '0');
    const mm = String(time.getMinutes()).padStart(2, '0');
    return `${hh}:${mm}`;
  },

  formatTimeLabel(timestamp) {
    const time = new Date(timestamp);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const day = new Date(time.getFullYear(), time.getMonth(), time.getDate());
    const hh = String(time.getHours()).padStart(2, '0');
    const mm = String(time.getMinutes()).padStart(2, '0');
    if (day.getTime() === today.getTime()) {
      return `今天 ${hh}:${mm}`;
    }
    if (day.getTime() === yesterday.getTime()) {
      return `昨天 ${hh}:${mm}`;
    }
    return `${time.getMonth() + 1}/${time.getDate()} ${hh}:${mm}`;
  },

  canRecallMessage(message) {
    if (!message || !message.fromMe) return false;
    if (message.deliveryStatus === 'failed') return false;
    if (message.canRecall === false) return false;
    if (message.canRecall === true) return true;
    const createdAt = Date.parse(message.createdAt || '');
    if (Number.isNaN(createdAt)) return false;
    return (Date.now() - createdAt) / 1000 <= RECALL_WINDOW_SECONDS;
  },

  rebuildMessageItems() {
    this.setData({
      messageItems: this.buildMessageItems(this.data.messages)
    });
  },

  setMessages(nextMessages) {
    this.setData({
      messages: nextMessages,
      messageItems: this.buildMessageItems(nextMessages)
    });
  },

  updateMessage(messageId, updater) {
    const nextMessages = this.data.messages.map(message => {
      if (message.id !== messageId) return message;
      return updater({ ...message });
    });
    this.setMessages(nextMessages);
  },

  appendMessage(message) {
    const nextMessages = this.data.messages.concat(message);
    this.setMessages(nextMessages);
  },

  replaceMessage(localId, nextMessage) {
    const nextMessages = this.data.messages.map(message => (
      message.id === localId ? nextMessage : message
    ));
    this.setMessages(nextMessages);
  },

  async onInput(event) {
    this.setData({ content: event.detail.value });
  },

  openPeerProfile() {
    if (!this.data.peerUserId) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${this.data.peerUserId}` });
  },

  openMyProfile() {
    if (!this.data.myUserId) return;
    wx.navigateTo({ url: `/pages/profile/public-user/index?id=${this.data.myUserId}` });
  },

  onMessageTap(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message) return;
    if (this.data.selectMode) {
      this.toggleSelect(message.id);
    }
  },

  onMessageLongPress(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message) return;
    if (this.data.selectMode) {
      this.toggleSelect(message.id);
      return;
    }

    const items = ['回复', '复制', '详情'];
    if (message.fromMe && this.canRecallMessage(message)) {
      items.push('撤回');
    }
    items.push('转发');
    items.push('选择');

    wx.showActionSheet({
      itemList: items,
      success: async (res) => {
        const action = items[res.tapIndex];
        if (action === '回复') {
          this.setData({
            replyToId: message.id,
            replyToContent: message.content || '',
            replyToSender: message.fromMe ? '我' : (message.senderAlias || '对方')
          });
        } else if (action === '复制') {
          wx.setClipboardData({ data: message.content || '' });
        } else if (action === '详情') {
          wx.showModal({
            title: '消息详情',
            content: this.buildMessageDetail(message),
            showCancel: false
          });
        } else if (action === '撤回') {
          await this.recallSingleMessage(message.id);
        } else if (action === '转发') {
          await this.openForwardPicker(message);
        } else if (action === '选择') {
          this.enterSelectMode(message.id);
        }
      }
    });
  },

  buildMessageDetail(message) {
    const lines = [
      `发送时间：${message.createdAt || ''}`,
      `发送方：${message.fromMe ? '我' : (message.senderAlias || '对方')}`,
      `状态：${message.deliveryStatus === 'recalled' || message.recalled ? '已撤回' : '正常'}`
    ];
    if (!message.fromMe && message.isRead) {
      lines.push('已读状态：已读');
    }
    if (message.hasReply || message.replyToContent) {
      lines.push(`回复：${message.replyToSender || '对方'} / ${message.replyToContent || ''}`);
    }
    return lines.join('\n');
  },

  clearReply() {
    this.setData({
      replyToId: '',
      replyToContent: '',
      replyToSender: ''
    });
  },

  dismissFirstMessageWarning() {
    this.setData({ firstMessageWarningDismissed: true });
  },

  async sendMessage() {
    const content = this.data.content.trim();
    if (!content || this.data.sending) return;
    const replyTarget = this.data.replyToId
      ? {
          id: this.data.replyToId,
          senderAlias: this.data.replyToSender,
          content: this.data.replyToContent
        }
      : null;
    const tempId = `temp-${Date.now()}`;
    const tempMessage = {
      id: tempId,
      content,
      createdAt: new Date().toISOString(),
      timeText: '刚刚',
      fromMe: true,
      senderAlias: '我',
      isRead: false,
      readAt: '',
      deliveryStatus: 'sending',
      canRecall: true,
      replyToId: replyTarget ? replyTarget.id : '',
      replyToSender: replyTarget ? replyTarget.senderAlias : '',
      replyToContent: replyTarget ? replyTarget.content : ''
    };
    this.setData({
      content: '',
      replyToId: '',
      replyToContent: '',
      replyToSender: '',
      sending: true
    });
    this.appendMessage(tempMessage);
    this.scrollToBottom();

    try {
      const sentMessage = await sendConversationMessage(this.data.conversationId, {
        content,
        replyToId: replyTarget ? replyTarget.id : ''
      });
      const finalMessage = this.decorateMessage({
        ...sentMessage,
        id: sentMessage.id || tempId,
        replyToId: sentMessage.replyToId || (replyTarget ? replyTarget.id : ''),
        replyToSender: sentMessage.replyToSender || (replyTarget ? replyTarget.senderAlias : ''),
        replyToContent: sentMessage.replyToContent || (replyTarget ? replyTarget.content : '')
      });
      this.replaceMessage(tempId, finalMessage);
    } catch (error) {
      this.replaceMessage(tempId, {
        ...tempMessage,
        timeText: '发送失败',
        deliveryStatus: 'failed',
        canRecall: false
      });
      wx.showToast({ title: `发送失败：${error}`, icon: 'none' });
    }

    this.setData({ sending: false });
    this.scrollToBottom();
  },

  async retrySend(event) {
    const index = Number(event.currentTarget.dataset.index);
    const message = this.data.messages[index];
    if (!message || this.data.sending) return;
    const replyTarget = message.replyToId
      ? {
          id: message.replyToId,
          senderAlias: message.replyToSender || '对方',
          content: message.replyToContent || ''
        }
      : null;

    this.replaceMessage(message.id, {
      ...message,
      deliveryStatus: 'sending',
      timeText: '刚刚',
      canRecall: true
    });
    this.setData({ sending: true });

    try {
      const sentMessage = await sendConversationMessage(this.data.conversationId, {
        content: message.content,
        replyToId: replyTarget ? replyTarget.id : ''
      });
      const finalMessage = this.decorateMessage({
        ...sentMessage,
        id: sentMessage.id || message.id,
        replyToId: sentMessage.replyToId || (replyTarget ? replyTarget.id : ''),
        replyToSender: sentMessage.replyToSender || (replyTarget ? replyTarget.senderAlias : ''),
        replyToContent: sentMessage.replyToContent || (replyTarget ? replyTarget.content : '')
      });
      this.replaceMessage(message.id, finalMessage);
    } catch (error) {
      this.replaceMessage(message.id, {
        ...message,
        deliveryStatus: 'failed',
        timeText: '发送失败',
        canRecall: false
      });
      wx.showToast({ title: `发送失败：${error}`, icon: 'none' });
    }

    this.setData({ sending: false });
  },

  async recallSingleMessage(messageId) {
    const message = this.data.messages.find(item => item.id === messageId);
    if (!message || (!message.canRecall && !this.canRecallMessage(message))) {
      wx.showToast({ title: '只能撤回 2 分钟内自己发送的消息', icon: 'none' });
      return;
    }
    try {
      await recallConversationMessage(this.data.conversationId, messageId);
      this.replaceMessage(messageId, {
        ...message,
        content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
        deliveryStatus: 'recalled',
        canRecall: false
      });
      if (this.data.replyToId === messageId) {
        this.clearReply();
      }
      wx.showToast({ title: '已撤回', icon: 'success' });
    } catch (error) {
      wx.showToast({ title: `撤回失败：${error}`, icon: 'none' });
    }
  },

  async batchRecall() {
    const selectedMessages = this.data.messages.filter(message => this.data.selectedMessageIds.includes(message.id));
    const recallableMessages = selectedMessages.filter(message => this.canRecallMessage(message));
    if (!recallableMessages.length) {
      wx.showToast({ title: '只能撤回 2 分钟内自己发送的消息', icon: 'none' });
      return;
    }
    wx.showModal({
      title: '批量撤回',
      content: `确定撤回选中的 ${recallableMessages.length} 条消息吗？`,
      confirmText: '撤回',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          for (const message of recallableMessages) {
            await recallConversationMessage(this.data.conversationId, message.id);
          }
          const recalledIds = new Set(recallableMessages.map(message => message.id));
          const nextMessages = this.data.messages.map(message => {
            if (!recalledIds.has(message.id)) return message;
            return {
              ...message,
              content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
              deliveryStatus: 'recalled',
              canRecall: false
            };
          });
          this.setData({
            messages: nextMessages,
            messageItems: this.buildMessageItems(nextMessages),
            selectMode: false,
            selectedMessageIds: []
          });
          if (this.data.replyToId && recalledIds.has(this.data.replyToId)) {
            this.clearReply();
          }
          wx.showToast({ title: `已撤回 ${recallableMessages.length} 条消息`, icon: 'success' });
        } catch (error) {
          wx.showToast({ title: `撤回失败：${error}`, icon: 'none' });
        }
      }
    });
  },

  enterSelectMode(messageId) {
    this.setData({
      selectMode: true,
      selectedMessageIds: [messageId]
    });
    this.rebuildMessageItems();
  },

  toggleSelect(eventOrMessageId) {
    const messageId = typeof eventOrMessageId === 'string'
      ? eventOrMessageId
      : eventOrMessageId.currentTarget.dataset.messageId;
    if (!messageId) return;
    const selected = new Set(this.data.selectedMessageIds);
    if (selected.has(messageId)) {
      selected.delete(messageId);
    } else {
      selected.add(messageId);
    }
    const selectedMessageIds = Array.from(selected);
    this.setData({
      selectedMessageIds,
      selectMode: selectedMessageIds.length > 0
    });
    this.rebuildMessageItems();
  },

  exitSelectMode() {
    this.setData({
      selectMode: false,
      selectedMessageIds: []
    });
    this.rebuildMessageItems();
  },

  async openForwardPicker(message) {
    try {
      const conversations = await getConversations();
      const forwardTargets = conversations.filter(item => item.id !== this.data.conversationId && !item.blockedByMe && !item.blockedByPeer);
      if (!forwardTargets.length) {
        wx.showToast({ title: '暂无可转发会话', icon: 'none' });
        return;
      }
      this._forwardMessage = message;
      this.setData({
        showForwardPicker: true,
        forwardTargets
      });
    } catch (error) {
      wx.showToast({ title: `转发失败：${error}`, icon: 'none' });
    }
  },

  closeForwardPicker() {
    this._forwardMessage = null;
    this.setData({
      showForwardPicker: false,
      forwardTargets: []
    });
  },

  async chooseForwardTarget(event) {
    const index = Number(event.currentTarget.dataset.index);
    const target = this.data.forwardTargets[index];
    const message = this._forwardMessage;
    if (!target || !message) return;
    try {
      await sendConversationMessage(target.id, {
        content: `[转发] ${message.content || ''}`
      });
      wx.showToast({ title: '已转发', icon: 'success' });
      this.closeForwardPicker();
    } catch (error) {
      wx.showToast({ title: `转发失败：${error}`, icon: 'none' });
    }
  },

  noop() {},

  async showOptionsSheet() {
    const action = this.data.blockedByMe ? '解除屏蔽' : '屏蔽对方';
    wx.showActionSheet({
      itemList: [action],
      success: async () => {
        await this.confirmToggleBlock();
      }
    });
  },

  async confirmToggleBlock() {
    const isBlocking = !this.data.blockedByMe;
    wx.showModal({
      title: isBlocking ? '屏蔽对方' : '解除屏蔽',
      content: isBlocking
        ? '确定要屏蔽对方吗？屏蔽后对方将无法给你发送消息。'
        : '确定要解除屏蔽吗？解除后对方可以继续给你发消息。',
      confirmText: isBlocking ? '屏蔽' : '解除屏蔽',
      confirmColor: '#ff3b30',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          if (isBlocking) {
            await blockConversationPeer(this.data.conversationId);
          } else {
            await unblockConversationPeer(this.data.conversationId);
          }
          this.setData({ blockedByMe: isBlocking });
          wx.showToast({ title: isBlocking ? '已屏蔽对方' : '已解除屏蔽', icon: 'success' });
        } catch (error) {
          wx.showToast({ title: `操作失败：${error}`, icon: 'none' });
        }
      }
    });
  },

  scrollToBottom() {
    setTimeout(() => {
      wx.pageScrollTo({
        scrollTop: 999999,
        duration: 160
      });
    }, 50);
  }
});
