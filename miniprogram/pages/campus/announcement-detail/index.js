Page({
  data: {
    title: '',
    content: '',
    createdAt: ''
  },

  onLoad(options) {
    const title = decodeURIComponent(options.title || '');
    wx.setNavigationBarTitle({ title: title || '公告详情' });
    this.setData({
      title,
      content: decodeURIComponent(options.content || ''),
      createdAt: decodeURIComponent(options.createdAt || '')
    });
  }
});
