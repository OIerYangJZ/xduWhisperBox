import { getBlocks, unblockUserGlobally } from '../../../../api/user';
import { requireLoginPage } from '../../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../../utils/theme_i18n';

Page({
  data: {
    loading: true,
    blocks: []
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadBlocks();
  },

  async loadBlocks() {
    this.setData({ loading: true });
    try {
      const blocks = await getBlocks();
      this.setData({ blocks, loading: false });
    } catch (error) {
      this.setData({ loading: false });
    }
  },

  onUnblockTap(event) {
    const targetUserId = event.currentTarget.dataset.id;
    const nickname = event.currentTarget.dataset.nickname || '该用户';
    if (!targetUserId) return;

    wx.showModal({
      title: '确认解除屏蔽',
      content: `确定将 ${nickname} 移出黑名单吗？`,
      success: async (res) => {
        if (res.confirm) {
          try {
            await unblockUserGlobally(targetUserId);
            // 乐观更新，过滤掉已解除的用户
            const updatedBlocks = this.data.blocks.filter((b) => b.id !== targetUserId);
            this.setData({ blocks: updatedBlocks });
            wx.showToast({
              title: '已移出黑名单',
              icon: 'success'
            });
          } catch (error) {
            console.error('[unblock error]', error);
          }
        }
      }
    });
  }
});
