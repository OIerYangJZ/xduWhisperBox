Page({
  data: {
    history: [
      { id: 1, title: "关于西电选课系统的使用方法", date: "今天 14:20" },
      { id: 2, title: "如何申请南北校区班车？", date: "昨天 09:15" },
      { id: 3, title: "奖学金评定最新政策解读", date: "3天前" }
    ]
  },

  onLoad() {
    // 页面加载逻辑
  },

  startNewChat() {
    wx.navigateTo({
      url: '/pages/ai/chat/index'
    });
  },

  continueChat(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({
      url: `/pages/ai/chat/index?id=${id}`
    });
  }
});
