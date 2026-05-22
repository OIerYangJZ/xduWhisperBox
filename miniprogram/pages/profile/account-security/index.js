import { getUserInfo } from '../../../api/auth';
import { submitCancellationRequest, submitLevelUpgradeRequest } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    profile: null,
    levelUpgradeSubtitle: '',
    cancellationSubtitle: '',
    submittingCancellation: false,
    submittingLevelUpgrade: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadProfile();
  },

  async loadProfile() {
    this.setData({ loading: true });
    try {
      const response = await getUserInfo();
      const profile = response.data || {};
      this.setData({
        profile,
        levelUpgradeSubtitle: profile.levelUpgradeRequest
          ? `${profile.levelUpgradeRequest.statusLabel || profile.levelUpgradeRequest.status} · ${profile.levelUpgradeRequest.createdAt || ''}`
          : '当前为二级用户，可申请升级为一级用户',
        cancellationSubtitle: profile.accountCancellationRequest
          ? `${profile.accountCancellationRequest.statusLabel || profile.accountCancellationRequest.status} · ${profile.accountCancellationRequest.createdAt || ''}`
          : '永久注销此账号及所有关联数据',
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  requestCancellation() {
    if (this.data.submittingCancellation || (this.data.profile && this.data.profile.accountCancellationRequest)) return;
    wx.showModal({
      title: '账号注销申请',
      editable: true,
      placeholderText: '请填写注销原因',
      confirmText: '提交',
      success: async (res) => {
        if (!res.confirm) return;
        const reason = String(res.content || '').trim();
        if (!reason) {
          wx.showToast({ title: '请填写原因', icon: 'none' });
          return;
        }
        this.setData({ submittingCancellation: true });
        wx.showLoading({ title: '提交中' });
        try {
          await submitCancellationRequest({ reason });
          wx.hideLoading();
          wx.showToast({ title: '已提交申请', icon: 'success' });
          await this.loadProfile();
        } catch (error) {
          wx.hideLoading();
        }
        this.setData({ submittingCancellation: false });
      }
    });
  },

  requestLevelUpgrade() {
    if (this.data.submittingLevelUpgrade || (this.data.profile && (this.data.profile.isLevelOneUser || this.data.profile.levelUpgradeRequest))) return;
    wx.showModal({
      title: '一级用户申请',
      editable: true,
      placeholderText: '请简述申请理由',
      confirmText: '提交',
      success: async (res) => {
        if (!res.confirm) return;
        const reason = String(res.content || '').trim();
        if (!reason) {
          wx.showToast({ title: '请填写理由', icon: 'none' });
          return;
        }
        this.setData({ submittingLevelUpgrade: true });
        wx.showLoading({ title: '提交中' });
        try {
          await submitLevelUpgradeRequest({ reason });
          wx.hideLoading();
          wx.showToast({ title: '已提交申请', icon: 'success' });
          await this.loadProfile();
        } catch (error) {
          wx.hideLoading();
        }
        this.setData({ submittingLevelUpgrade: false });
      }
    });
  },

  goResetPassword() {
    wx.navigateTo({ url: '/pages/profile/reset-password/index' });
  }
});
