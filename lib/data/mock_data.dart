import '../models/post_item.dart';

const List<String> kChannels = <String>[
  '综合',
  '找对象',
  '找搭子',
  '交友扩列',
  '吐槽日常',
  '八卦吃瓜',
  '求助问答',
  '失物招领',
  '二手交易',
  '学习交流',
  '活动拼车',
  '其他',
];

final List<PostItem> mockPosts = <PostItem>[
  PostItem(
    id: 'p1',
    title: '求助：图书馆哪里插座最多？',
    content: '这周赶大作业，想找一个相对安静而且插座多的位置，北校区优先。',
    channel: '求助问答',
    tags: <String>['学习', '北校区'],
    authorAlias: '洞主-青橙',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    hasImage: false,
    commentCount: 24,
    likeCount: 52,
    favoriteCount: 19,
    status: PostStatus.ongoing,
    allowComment: true,
    allowDm: true,
  ),
  PostItem(
    id: 'p2',
    title: '找周末羽毛球搭子',
    content: '周六下午操场旁边羽毛球馆，水平一般，主打一起运动。',
    channel: '找搭子',
    tags: <String>['运动', '周末'],
    authorAlias: '洞主-极光',
    createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 13)),
    hasImage: true,
    commentCount: 11,
    likeCount: 33,
    favoriteCount: 9,
    status: PostStatus.ongoing,
    allowComment: true,
    allowDm: true,
  ),
  PostItem(
    id: 'p3',
    title: '二手显示器出一个 24 寸',
    content: '毕业清东西，成色还不错，支持当面看货。',
    channel: '二手交易',
    tags: <String>['数码', '毕业季'],
    authorAlias: '洞主-小行星',
    createdAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 45)),
    hasImage: true,
    commentCount: 16,
    likeCount: 28,
    favoriteCount: 34,
    status: PostStatus.ongoing,
    allowComment: true,
    allowDm: true,
  ),
  PostItem(
    id: 'p4',
    title: '吐槽：食堂晚高峰排队太久',
    content: '今天排了 25 分钟，想知道有没有错峰吃饭攻略。',
    channel: '吐槽日常',
    tags: <String>['食堂', '日常'],
    authorAlias: '洞主-银杏',
    createdAt: DateTime.now().subtract(const Duration(hours: 8, minutes: 4)),
    hasImage: false,
    commentCount: 42,
    likeCount: 66,
    favoriteCount: 21,
    status: PostStatus.resolved,
    allowComment: true,
    allowDm: false,
  ),
  PostItem(
    id: 'p5',
    title: '失物招领：一卡通一张',
    content: '南校区教学楼 A 座门口捡到一卡通，已交保卫处。',
    channel: '失物招领',
    tags: <String>['南校区', '一卡通'],
    authorAlias: '洞主-晨雾',
    createdAt: DateTime.now().subtract(const Duration(hours: 12, minutes: 17)),
    hasImage: false,
    commentCount: 7,
    likeCount: 39,
    favoriteCount: 48,
    status: PostStatus.closed,
    allowComment: true,
    allowDm: false,
  ),
];

final Map<String, List<String>> mockCommentsByPostId = <String, List<String>>{
  'p1': <String>[
    '教研楼三层东边插座比较多。',
    '新图二层靠窗位置不错，但中午人多。',
    '建议带排插，稳一点。',
  ],
  'p2': <String>[
    '我周六有空，已申请私信。',
    '可以加上球馆具体时段。',
  ],
  'p3': <String>[
    '请问还能刀吗？',
    '支持当面验货很加分。',
  ],
};

final List<Map<String, String>> mockDmRequests = <Map<String, String>>[
  <String, String>{
    'from': '同学-海盐',
    'reason': '想咨询图书馆座位信息',
    'time': '10 分钟前',
  },
  <String, String>{
    'from': '同学-留白',
    'reason': '想问二手显示器细节',
    'time': '1 小时前',
  },
];

final List<Map<String, String>> mockConversations = <Map<String, String>>[
  <String, String>{
    'name': '同学-海盐',
    'lastMessage': '谢谢，已经找到位置了。',
    'time': '14:23',
  },
  <String, String>{
    'name': '同学-留白',
    'lastMessage': '今晚可以面交吗？',
    'time': '昨天',
  },
];

final List<Map<String, String>> mockMyComments = <Map<String, String>>[
  <String, String>{
    'post': '求助：图书馆哪里插座最多？',
    'content': '北校图书馆三楼靠窗区域可冲。',
    'time': '今天 11:20',
  },
  <String, String>{
    'post': '吐槽：食堂晚高峰排队太久',
    'content': '可以 11:20 或 17:00 前后去。',
    'time': '昨天 19:10',
  },
];

final List<Map<String, String>> mockMyReports = <Map<String, String>>[
  <String, String>{
    'target': '帖子 p6',
    'reason': '广告引流',
    'status': '处理中',
  },
  <String, String>{
    'target': '评论 c9',
    'reason': '人身攻击',
    'status': '已处理：内容删除',
  },
];
