import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    version: '',
    items: [
      { label: '用户协议', type: 'user-agreement', subtitle: '查看平台服务条款', icon: '□' },
      { label: '隐私政策', type: 'privacy-policy', subtitle: '查看个人信息与数据处理说明', icon: '◈' },
      { label: '社区规范', type: 'community-guidelines', subtitle: '了解发帖与互动规则', icon: '◇' },
      { label: '举报说明', type: 'report-guidelines', subtitle: '了解举报受理与处理流程', icon: '!' }
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

  openFeedback() {
    wx.navigateTo({ url: '/pages/profile/feedback/index' });
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
