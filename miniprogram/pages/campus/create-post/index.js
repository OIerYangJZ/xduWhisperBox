import { createPost, getChannels } from '../../../api/posts';
import { uploadPostImage } from '../../../api/uploads';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const MAX_IMAGE_COUNT = 9;
const MAX_IMAGE_SIZE = 5 * 1024 * 1024;
const STATUS_OPTIONS = [
  { label: '进行中', value: 'ongoing' },
  { label: '已解决', value: 'resolved' },
  { label: '已结束', value: 'closed' }
];
const VISIBILITY_OPTIONS = [
  { label: '公开', value: 'public' },
  { label: '私密', value: 'private' }
];
const PIN_OPTIONS = [
  { label: '不置顶', value: 0 },
  { label: '1 小时', value: 60 },
  { label: '6 小时', value: 360 },
  { label: '1 天', value: 1440 },
  { label: '3 天', value: 4320 }
];
const TAG_OPTIONS = ['求助', '吐槽', '拼车', '二手', '课程', '活动', '失物', '情感'];
const ALIAS_WORDS = ['风信子', '银杏叶', '南校同学', '北校同学', '图书馆夜猫', '操场晚风'];

Page({
  data: {
    channels: ['综合'],
    channelIndex: 0,
    title: '',
    content: '',
    tagText: '',
    tagOptions: TAG_OPTIONS.map((label) => ({ label, selected: false })),
    selectedTags: [],
    statusOptions: STATUS_OPTIONS,
    statusIndex: 0,
    visibilityOptions: VISIBILITY_OPTIONS,
    visibilityIndex: 0,
    pinOptions: PIN_OPTIONS,
    pinIndex: 0,
    allowComment: true,
    allowDm: true,
    contentFormat: 'plain',
    useAnonymousAlias: true,
    anonymousAlias: '',
    images: [],
    submitting: false
  },

  onLoad() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadChannels();
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    if (this.data.channels.length <= 1) {
      this.loadChannels();
    }
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

  onStatusChange(event) {
    this.setData({ statusIndex: Number(event.detail.value || 0) });
  },

  onVisibilityChange(event) {
    this.setData({ visibilityIndex: Number(event.detail.value || 0) });
  },

  onPinChange(event) {
    this.setData({ pinIndex: Number(event.detail.value || 0) });
  },

  onAllowCommentChange(event) {
    this.setData({ allowComment: event.detail.value });
  },

  onAllowDmChange(event) {
    this.setData({ allowDm: event.detail.value });
  },


  onAnonymousChange(event) {
    const useAnonymousAlias = event.detail.value;
    this.setData({
      useAnonymousAlias,
      allowDm: useAnonymousAlias ? false : this.data.allowDm
    });
  },

  toggleTag(event) {
    const tag = event.currentTarget.dataset.tag;
    if (!tag) return;
    const selectedTags = this.data.selectedTags.slice();
    const tagOptions = this.data.tagOptions.map((item) => ({ ...item }));
    const index = selectedTags.indexOf(tag);
    if (index >= 0) {
      selectedTags.splice(index, 1);
    } else {
      if (selectedTags.length >= 5) {
        wx.showToast({ title: '最多选择 5 个标签', icon: 'none' });
        return;
      }
      selectedTags.push(tag);
    }
    tagOptions.forEach((item) => {
      item.selected = selectedTags.indexOf(item.label) >= 0;
    });
    this.setData({ selectedTags, tagOptions });
  },

  randomAlias() {
    const index = Math.floor(Math.random() * ALIAS_WORDS.length);
    this.setData({ anonymousAlias: ALIAS_WORDS[index] });
  },

  chooseImages() {
    const remain = MAX_IMAGE_COUNT - this.data.images.length;
    if (remain <= 0) {
      wx.showToast({ title: '最多添加 9 张图片', icon: 'none' });
      return;
    }

    const onPicked = (files) => {
      const rows = files
        .map((file) => ({
          path: file.tempFilePath || file.path || '',
          size: Number(file.size || 0)
        }))
        .filter((file) => file.path);
      const validRows = rows.filter((file) => file.size <= MAX_IMAGE_SIZE);
      if (validRows.length !== rows.length) {
        wx.showToast({ title: '单张图片不能超过 5MB', icon: 'none' });
      }
      this.setData({
        images: [
          ...this.data.images,
          ...validRows.slice(0, remain).map((file) => ({
            localPath: file.path,
            size: file.size,
            uploading: false,
            uploadedId: '',
            url: ''
          }))
        ]
      });
    };

    if (wx.chooseMedia) {
      wx.chooseMedia({
        count: remain,
        mediaType: ['image'],
        sizeType: ['compressed'],
        sourceType: ['album', 'camera'],
        success: (res) => onPicked(res.tempFiles || [])
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
        const files = paths.map((path, index) => ({
          tempFilePath: path,
          size: Number((tempFiles[index] && tempFiles[index].size) || 0)
        }));
        onPicked(files);
      }
    });
  },

  previewImage(event) {
    const current = event.currentTarget.dataset.path;
    const urls = this.data.images.map((item) => item.localPath);
    if (current) wx.previewImage({ current, urls });
  },

  removeImage(event) {
    const index = Number(event.currentTarget.dataset.index);
    const images = this.data.images.slice();
    images.splice(index, 1);
    this.setData({ images });
  },

  async uploadSelectedImages() {
    const uploadIds = [];
    const images = this.data.images.slice();
    for (let index = 0; index < images.length; index += 1) {
      const image = images[index];
      if (image.uploadedId) {
        uploadIds.push(image.uploadedId);
        continue;
      }
      images[index] = { ...image, uploading: true };
      this.setData({ images });
      let upload;
      try {
        upload = await uploadPostImage(image.localPath);
      } catch (error) {
        images[index] = { ...image, uploading: false };
        this.setData({ images });
        throw error;
      }
      images[index] = {
        ...image,
        uploading: false,
        uploadedId: upload.id,
        url: upload.url,
        status: upload.status || ''
      };
      uploadIds.push(upload.id);
      this.setData({ images });
    }
    return uploadIds;
  },

  async submitPost() {
    if (this.data.submitting) return;
    const content = this.data.content.trim();
    if (!content) {
      wx.showToast({ title: '请输入正文', icon: 'none' });
      return;
    }
    const customTags = this.data.tagText
      .split(/[,\s，、#]+/)
      .map((item) => item.trim())
      .filter(Boolean);
    const tags = Array.from(new Set([...this.data.selectedTags, ...customTags])).slice(0, 5);
    const status = this.data.statusOptions[this.data.statusIndex].value;
    const visibility = this.data.visibilityOptions[this.data.visibilityIndex].value;
    const pinDurationMinutes = Number(this.data.pinOptions[this.data.pinIndex].value || 0);
    const contentFormat = this.data.contentFormat;

    this.setData({ submitting: true });
    wx.showLoading({ title: '发布中' });
    try {
      const imageIds = await this.uploadSelectedImages();
      const post = await createPost({
        title: this.data.title.trim(),
        content,
        channel: this.data.channels[this.data.channelIndex] || '综合',
        tags,
        imageIds,
        status,
        visibility,
        allowComment: this.data.allowComment,
        allowDm: this.data.allowDm,
        contentFormat,
        markdownSource: contentFormat === 'markdown' ? content : '',
        ...(pinDurationMinutes > 0 ? { pinDurationMinutes } : {}),
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
