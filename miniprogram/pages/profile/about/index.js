Page({
  data: {
    version: '',
    items: [
      { label: '用户协议', type: 'user-agreement' },
      { label: '隐私政策', type: 'privacy-policy' },
      { label: '社区规范', type: 'community-guidelines' },
      { label: '致谢', type: 'acknowledgements' }
    ]
  },

  onLoad() {
    const accountInfo = wx.getAccountInfoSync ? wx.getAccountInfoSync() : {};
    const miniProgram = accountInfo.miniProgram || {};
    this.setData({ version: miniProgram.version || '开发版' });
  },

  openLegal(event) {
    const type = event.currentTarget.dataset.type;
    if (type) wx.navigateTo({ url: `/pages/profile/legal/index?type=${type}` });
  },

  checkUpdate() {
    const manager = wx.getUpdateManager && wx.getUpdateManager();
    if (!manager) {
      wx.showToast({ title: '当前版本无需更新', icon: 'none' });
      return;
    }
    manager.onCheckForUpdate((res) => {
      wx.showToast({ title: res.hasUpdate ? '发现新版本' : '已是最新版本', icon: 'none' });
    });
  }
});
