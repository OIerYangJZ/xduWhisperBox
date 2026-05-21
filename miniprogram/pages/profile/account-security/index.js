import { getUserInfo } from '../../../api/auth';
import { submitCancellationRequest, submitLevelUpgradeRequest } from '../../../api/user';
import { requireLoginPage } from '../../../utils/auth_guard';

Page({
  data: {
    loading: true,
    profile: null,
    submittingCancellation: false,
    submittingLevelUpgrade: false
  },

  onShow() {
    if (!requireLoginPage()) return;
    this.loadProfile();
  },

  async loadProfile() {
    this.setData({ loading: true });
    try {
      const response = await getUserInfo();
      this.setData({
        profile: response.data || {},
        loading: false
      });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  requestCancellation() {
    if (this.data.submittingCancellation) return;
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
    if (this.data.submittingLevelUpgrade) return;
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