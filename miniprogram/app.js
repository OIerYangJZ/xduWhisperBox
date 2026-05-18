App({
  globalData: {
    appName: '西电树洞',
    clientType: 'wechat-miniprogram'
  },

  onLaunch() {
    const token = wx.getStorageSync('token');
    this.globalData.hasToken = Boolean(token);
  }
});
