import { createPost, getChannels } from '../../../api/posts';
import { uploadPostImage } from '../../../api/uploads';
import { requireLoginPage } from '../../../utils/auth_guard';

const MAX_IMAGE_COUNT = 9;
const MAX_IMAGE_SIZE = 5 * 1024 * 1024;

Page({
  data: {
    channels: ['综合'],
    channelIndex: 0,
    title: '',
    content: '',
    tagText: '',
    useAnonymousAlias: true,
    anonymousAlias: '',
    images: [],
    submitting: false
  },

  onLoad() {
    if (!requireLoginPage()) return;
    this.loadChannels();
  },

  onShow() {
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

  onAnonymousChange(event) {
    this.setData({ useAnonymousAlias: event.detail.value });
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
    const tags = this.data.tagText
      .split(/[,\s，、#]+/)
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 5);

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
