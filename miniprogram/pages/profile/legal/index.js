const CONTENT = {
  'user-agreement': {
    title: '用户协议',
    sections: [
      {
        heading: '账号与使用',
        body: '你需要使用真实可用的校园邮箱或平台支持的身份方式注册。账号仅供本人使用，请妥善保管登录凭据。'
      },
      {
        heading: '内容发布',
        body: '你应对自己发布的帖子、评论、图片和反馈负责。请勿发布违法违规、骚扰攻击、广告引流、侵犯隐私或破坏社区秩序的内容。'
      },
      {
        heading: '平台处理',
        body: '平台会根据社区规范处理违规内容，包括隐藏、删除、限制互动、封禁账号和配合必要的合规处置。'
      }
    ]
  },
  'privacy-policy': {
    title: '隐私政策',
    sections: [
      {
        heading: '收集范围',
        body: '平台会收集注册邮箱、昵称、头像、学号认证结果、发布内容、互动记录、举报记录和必要的设备请求信息，用于登录、社区互动、审核和安全治理。'
      },
      {
        heading: '匿名展示',
        body: '匿名内容在前台隐藏真实账号信息，但服务端仍保存必要映射，用于举报处理、风控审核和合规追责。'
      },
      {
        heading: '隐私控制',
        body: '你可以在设置中调整陌生人私信和联系入口展示，也可以提交账号注销申请。'
      }
    ]
  },
  'community-guidelines': {
    title: '社区规范/举报说明',
    sections: [
      {
        heading: '表达边界',
        body: '欢迎真实、友善、理性的校园讨论。禁止人身攻击、恶意造谣、歧视辱骂、泄露隐私、低俗色情、诈骗广告和其他违法违规内容。'
      },
      {
        heading: '举报处理',
        body: '你可以对帖子或评论提交举报，管理员会结合内容、上下文和历史记录处理，并通过通知中心反馈结果。'
      },
      {
        heading: '申诉与修正',
        body: '如果你认为处理结果有误，可以通过反馈或申诉渠道说明情况，平台会重新核查。'
      }
    ]
  },
  acknowledgements: {
    title: '致谢',
    sections: [
      {
        heading: '项目说明',
        body: 'XDU WhisperBox 由校园社区需求驱动，感谢参与测试、反馈问题和维护内容秩序的同学。'
      },
      {
        heading: '技术生态',
        body: '项目使用微信小程序、Flutter Web、Python 标准库 HTTP 服务、SQLite、Riverpod 等技术构建。'
      }
    ]
  }
};

Page({
  data: {
    title: '',
    sections: []
  },

  onLoad(options) {
    const type = options.type || 'user-agreement';
    const item = CONTENT[type] || CONTENT['user-agreement'];
    wx.setNavigationBarTitle({ title: item.title });
    this.setData(item);
  }
});
