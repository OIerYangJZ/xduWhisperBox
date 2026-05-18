import { createPost, getChannels } from '../../../api/posts';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    channels: ['综合'],
    channelIndex: 0,
    title: '',
    content: '',
    tagText: '',
    useAnonymousAlias: true,
    anonymousAlias: '',
    submitting: false
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this.loadChannels();
  },

  onShow() {
    requireLoginPage();
  },

  async loadChannels() {
    const channels = await getChannels();
    this.setData({ channels: channels.length ? channels : ['综合'] });
  },

  onTitleInput(event) {
    this.setData({ title: event.detail.value });
  },

  onContentInput(event) {
    this.setData({ content: event.detail.value });
  },

  onTagInput(event) {
    this.setData({ tagText: event.detail.value });
  },

  onAliasInput(event) {
    this.setData({ anonymousAlias: event.detail.value });
  },

  onChannelChange(event) {
    this.setData({ channelIndex: Number(event.detail.value || 0) });
  },

  onAnonymousChange(event) {
    this.setData({ useAnonymousAlias: event.detail.value });
  },

  async submitPost() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入正文', icon: 'none' });
      return;
    }
    const tags = this.data.tagText
      .split(/[,\s，、#]+/)
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 5);

    this.setData({ submitting: true });
    wx.showLoading({ title: '发布中' });
    try {
      const post = await createPost({
        title: this.data.title.trim(),
        content,
        channel: this.data.channels[this.data.channelIndex] || '综合',
        tags,
        status: 'ongoing',
        visibility: 'public',
        useAnonymousAlias: this.data.useAnonymousAlias,
        anonymousAlias: this.data.anonymousAlias.trim()
      });
      wx.hideLoading();
      wx.showToast({ title: '已发布', icon: 'success' });
      setTimeout(() => {
        wx.redirectTo({ url: `/pages/campus/post-detail/index?id=${post.id}` });
      }, 700);
    } catch (error) {
      wx.hideLoading();
      this.setData({ submitting: false });
    }
  }
});
