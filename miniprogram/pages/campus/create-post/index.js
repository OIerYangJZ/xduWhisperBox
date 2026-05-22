import { getUserInfo } from '../../../api/auth';
import { createPost, getChannels } from '../../../api/posts';
import { uploadPostImage } from '../../../api/uploads';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const MAX_IMAGE_COUNT = 9;
const CONTENT_LIMIT = 2000;
const TITLE_LIMIT = 50;
const STATUS_OPTIONS = [
  { label: '进行中', value: 'ongoing', icon: 'help' },
  { label: '已解决', value: 'resolved', icon: 'check' },
  { label: '已结束', value: 'closed', icon: 'lock' }
];
const PIN_OPTIONS = [
  { label: '不置顶', minutes: null },
  { label: '30 分钟', minutes: 30 },
  { label: '1 小时', minutes: 60 },
  { label: '2 小时', minutes: 120 },
  { label: '3 小时', minutes: 180 },
  { label: '1 天', minutes: 1440 },
  { label: '3 天', minutes: 4320 }
];
const TAG_OPTIONS = [
  '求助',
  '学习',
  '二手',
  '组队',
  '经验',
  '吐槽',
  '交友',
  '活动',
  '租房',
  '实习',
  '考研',
  '保研',
  '出国',
  '竞赛',
  '社团'
];
const VISIBILITY_OPTIONS = [
  { label: '所有人可见', value: 'public', icon: 'public' },
  { label: '仅自己可见', value: 'private', icon: 'lock' }
];
const ALIAS_WORDS = ['神秘', '路过的', '隔壁的', '匿名的', '安静的', '好奇的', '悠闲的', '低调的'];
const ALIAS_NOUNS = ['同学', '路人', '学长', '学弟', '学妹', '小伙伴', '小伙伴', '小伙伴'];

function buildTagOptions(selectedTags) {
  return TAG_OPTIONS.map((label) => ({
    label,
    selected: selectedTags.includes(label)
  }));
}

function generateAnonymousAlias() {
  const now = Date.now();
  const adj = ALIAS_WORDS[Math.floor(now / 13) % ALIAS_WORDS.length];
  const noun = ALIAS_NOUNS[Math.floor(now / 17) % ALIAS_NOUNS.length];
  return `${adj}${noun}`;
}

Page({
  data: {
    navTop: 0,
    navHeight: 0,
    loading: true,
    channels: ['综合'],
    channelIndex: 0,
    channelSelectorOpen: false,

    title: '',
    content: '',
    contentLength: 0,
    canPublish: false,

    tags: [],
    tagDraft: [],
    tagSelectorOpen: false,
    customTagText: '',
    tagOptions: buildTagOptions([]),

    statusOptions: STATUS_OPTIONS,
    postStatusIndex: 0,
    statusSelectorOpen: false,

    pinOptions: PIN_OPTIONS,
    pinIndex: 0,
    pinSelectorOpen: false,
    isLevelOneUser: false,

    useAnonymousAlias: false,
    anonymousAlias: '',

    visibilityOptions: VISIBILITY_OPTIONS,
    privateOnly: false,
    visibilitySelectorOpen: false,

    images: [],
    isUploading: false,
    isPublishing: false
  },

  onLoad() {
    this.initCustomNav();
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadChannels();
    this.loadUserLevel();
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
  },

  initCustomNav() {
    const menuButton = wx.getMenuButtonBoundingClientRect();
    this.setData({
      navTop: menuButton.top,
      navHeight: menuButton.height
    });
  },

  async loadChannels() {
    try {
      const channels = await getChannels();
      const rows = channels.filter((channel) => channel !== '全部');
      this.setData({
        channels: rows.length ? rows : ['综合']
      });
    } catch (error) {
      this.setData({
        channels: ['综合', '学习', '吐槽日常', '失物招领', '二手交易', '找搭子']
      });
    } finally {
      this.setData({ loading: false });
    }
  },

  async loadUserLevel() {
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      this.setData({ isLevelOneUser: Boolean(profile.isLevelOneUser) });
    } catch (error) {}
  },

  updatePublishState(nextContent) {
    const content = nextContent == null ? this.data.content : nextContent;
    this.setData({
      contentLength: content.length,
      canPublish: content.trim().length > 0 && !this.data.isPublishing
    });
  },

  closeInlineSelectors() {
    this.setData({
      channelSelectorOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onTitleInput(event) {
    this.setData({ title: event.detail.value.slice(0, TITLE_LIMIT) });
  },

  onContentInput(event) {
    const value = event.detail.value.slice(0, CONTENT_LIMIT);
    this.setData({
      content: value,
      contentLength: value.length,
      canPublish: value.trim().length > 0 && !this.data.isPublishing
    });
  },

  toggleChannelSelector() {
    this.setData({
      channelSelectorOpen: !this.data.channelSelectorOpen,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onChannelTap(event) {
    const channel = event.currentTarget.dataset.channel;
    const index = this.data.channels.indexOf(channel);
    if (index < 0) return;
    this.setData({
      channelIndex: index,
      channelSelectorOpen: false
    });
  },

  toggleTagSelector() {
    if (this.data.tagSelectorOpen) {
      this.setData({ tagSelectorOpen: false });
      return;
    }
    this.setData({
      tagDraft: this.data.tags.slice(),
      customTagText: '',
      tagOptions: buildTagOptions(this.data.tags),
      tagSelectorOpen: true,
      channelSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onCustomTagInput(event) {
    this.setData({ customTagText: event.detail.value });
  },

  toggleDraftTag(event) {
    const tag = event.currentTarget.dataset.tag;
    if (!tag) return;
    const tagDraft = this.data.tagDraft.slice();
    const index = tagDraft.indexOf(tag);
    if (index >= 0) {
      tagDraft.splice(index, 1);
    } else if (tagDraft.length < 5) {
      tagDraft.push(tag);
    }
    this.setData({ tagDraft, tagOptions: buildTagOptions(tagDraft) });
  },

  addCustomTag() {
    const input = this.data.customTagText.trim();
    if (!input) return;
    const rows = input
      .split(/[,\s，\n]+/)
      .map((item) => item.trim())
      .filter(Boolean);
    if (!rows.length) return;
    const tagDraft = this.data.tagDraft.slice();
    rows.forEach((tag) => {
      if (tagDraft.length >= 5) return;
      if (!tagDraft.includes(tag)) tagDraft.push(tag);
    });
    this.setData({ tagDraft, customTagText: '', tagOptions: buildTagOptions(tagDraft) });
  },

  confirmTags() {
    this.setData({
      tags: this.data.tagDraft.slice(0, 5),
      tagOptions: buildTagOptions(this.data.tagDraft.slice(0, 5)),
      tagSelectorOpen: false
    });
  },

  closeTagSelector() {
    this.setData({ tagSelectorOpen: false });
  },

  removeTag(event) {
    const tag = event.currentTarget.dataset.tag;
    const tags = this.data.tags.filter((item) => item !== tag);
    this.setData({ tags, tagOptions: buildTagOptions(tags) });
  },

  toggleStatusSelector() {
    this.setData({
      statusSelectorOpen: !this.data.statusSelectorOpen,
      channelSelectorOpen: false,
      tagSelectorOpen: false,
      pinSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onStatusTap(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    this.setData({
      postStatusIndex: index,
      statusSelectorOpen: false
    });
  },

  togglePinSelector() {
    if (!this.data.isLevelOneUser) return;
    this.setData({
      pinSelectorOpen: !this.data.pinSelectorOpen,
      channelSelectorOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      visibilitySelectorOpen: false
    });
  },

  onPinTap(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    this.setData({
      pinIndex: index,
      pinSelectorOpen: false
    });
  },

  toggleAnonymous() {
    const useAnonymousAlias = !this.data.useAnonymousAlias;
    this.setData({
      useAnonymousAlias,
      anonymousAlias: useAnonymousAlias ? generateAnonymousAlias() : ''
    });
  },

  onAnonymousAliasInput(event) {
    this.setData({ anonymousAlias: event.detail.value.slice(0, 20) });
  },

  toggleVisibilitySelector() {
    this.setData({
      visibilitySelectorOpen: !this.data.visibilitySelectorOpen,
      channelSelectorOpen: false,
      tagSelectorOpen: false,
      statusSelectorOpen: false,
      pinSelectorOpen: false
    });
  },

  onVisibilityTap(event) {
    const value = event.currentTarget.dataset.value;
    this.setData({
      privateOnly: value === 'private',
      visibilitySelectorOpen: false
    });
  },

  chooseImages() {
    const remain = MAX_IMAGE_COUNT - this.data.images.length;
    if (remain <= 0) return;
    const handlePicked = (files) => {
      const rows = files
        .map((file) => ({
          localPath: file.tempFilePath || file.path || '',
          size: Number(file.size || 0)
        }))
        .filter((file) => file.localPath)
        .slice(0, remain);
      if (!rows.length) return;
      const nextImages = [
        ...this.data.images,
        ...rows.map((file) => ({
          localPath: file.localPath,
          size: file.size,
          uploading: false,
          uploadedId: '',
          url: ''
        }))
      ];
      this.setData({ images: nextImages });
      this.uploadPendingImages();
    };

    if (wx.chooseMedia) {
      wx.chooseMedia({
        count: remain,
        mediaType: ['image'],
        sizeType: ['compressed'],
        sourceType: ['album', 'camera'],
        success: (res) => handlePicked(res.tempFiles || [])
      });
      return;
    }

    wx.chooseImage({
      count: remain,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const paths = res.tempFilePaths || [];
        const tempFiles = res.tempFiles || [];
        handlePicked(
          paths.map((path, index) => ({
            tempFilePath: path,
            size: Number((tempFiles[index] && tempFiles[index].size) || 0)
          }))
        );
      }
    });
  },

  previewImage(event) {
    const current = event.currentTarget.dataset.path;
    const urls = this.data.images.map((item) => item.localPath);
    if (current && urls.length) {
      wx.previewImage({ current, urls });
    }
  },

  removeImage(event) {
    const index = Number(event.currentTarget.dataset.index || 0);
    const images = this.data.images.slice();
    images.splice(index, 1);
    this.setData({ images });
  },

  async uploadPendingImages() {
    if (this.data.isUploading) return;
    const pending = this.data.images.filter((item) => !item.uploadedId);
    if (!pending.length) return;

    this.setData({ isUploading: true });
    const images = this.data.images.slice();
    try {
      for (let index = 0; index < images.length; index += 1) {
        if (images[index].uploadedId) continue;
        images[index] = { ...images[index], uploading: true };
        this.setData({ images });
        const uploaded = await uploadPostImage(images[index].localPath);
        images[index] = {
          ...images[index],
          uploading: false,
          uploadedId: uploaded.id || '',
          url: uploaded.url || ''
        };
        this.setData({ images });
      }
    } catch (error) {
      const resetImages = images.map((item) => ({ ...item, uploading: false }));
      this.setData({ images: resetImages });
    } finally {
      this.setData({ isUploading: false });
    }
  },

  async submitPost() {
    if (!this.data.canPublish || this.data.isPublishing) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入帖子内容', icon: 'none' });
      return;
    }

    this.setData({ isPublishing: true, canPublish: false });
    wx.showLoading({ title: '发布中' });
    try {
      await this.uploadPendingImages();
      const uploadedImageIds = this.data.images
        .map((item) => item.uploadedId)
        .filter(Boolean);
      const pinMinutes = PIN_OPTIONS[this.data.pinIndex].minutes;
      const anonymousAlias = this.data.anonymousAlias.trim();
      const payload = {
        title: this.data.title.trim(),
        content,
        contentFormat: 'plain',
        channel: this.data.channels[this.data.channelIndex] || '综合',
        tags: this.data.tags.slice(0, 5),
        allowComment: true,
        allowDm: !this.data.useAnonymousAlias,
        visibility: this.data.privateOnly ? 'private' : 'public',
        status: STATUS_OPTIONS[this.data.postStatusIndex].value,
        hasImage: this.data.images.length > 0,
        imageUploadIds: uploadedImageIds,
        useAnonymousAlias: this.data.useAnonymousAlias
      };

      if (pinMinutes != null && pinMinutes > 0) {
        payload.pinDurationMinutes = pinMinutes;
      }
      if (this.data.useAnonymousAlias && anonymousAlias) {
        payload.anonymousAlias = anonymousAlias;
      }

      await createPost(payload);
      wx.hideLoading();
      wx.showToast({ title: '发布成功！', icon: 'success' });
      setTimeout(() => {
        wx.navigateBack();
      }, 250);
    } catch (error) {
      wx.hideLoading();
      wx.showToast({ title: '发布失败', icon: 'none' });
      this.setData({ isPublishing: false }, () => {
        this.updatePublishState();
      });
    }
  },

  confirmDiscard() {
    if (
      !this.data.title.trim() &&
      !this.data.content.trim() &&
      !this.data.images.length
    ) {
      wx.navigateBack();
      return;
    }
    wx.showModal({
      title: '放弃编辑？',
      content: '确定要放弃当前编辑内容吗？',
      cancelText: '取消',
      confirmText: '放弃',
      confirmColor: '#ff3b30',
      success: (res) => {
        if (res.confirm) {
          wx.navigateBack();
        }
      }
    });
  }
});
