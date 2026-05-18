import { getChannels, getPosts } from './posts';
import { truncate } from '../utils/format';

const localAnswer = (question) => {
  const text = question.trim();
  if (/登录|注册|账号|密码/.test(text)) {
    return '请使用西电学生邮箱或学号登录。账号异常、忘记密码等问题建议先在 Web/App 端完成处理。';
  }
  if (/发帖|树洞|匿名/.test(text)) {
    return '发帖入口在校园页和树洞列表右上角。匿名发帖会在前台隐藏真实身份，后台仍保留必要的审核追溯信息。';
  }
  if (/举报|审核|违规/.test(text)) {
    return '帖子详情页可以发起举报。举报会进入管理员后台处理，处理结果会通过通知中心反馈。';
  }
  if (/收藏|点赞|评论/.test(text)) {
    return '帖子详情页支持点赞、收藏和评论；收藏内容可以在“我的收藏”中查看。';
  }
  return '';
};

export const getAiHomeData = async () => {
  const [channels, hotPosts] = await Promise.all([
    getChannels(),
    getPosts({ sort: 'hot' })
  ]);
  return {
    channels,
    hotPosts: hotPosts.slice(0, 5)
  };
};

export const askCampusAssistant = async (question) => {
  const keyword = question.trim();
  const [matchedPosts, latestPosts] = await Promise.all([
    keyword ? getPosts({ keyword, sort: 'hot' }) : Promise.resolve([]),
    getPosts({ sort: 'latest' })
  ]);

  const local = localAnswer(keyword);
  const posts = (matchedPosts.length ? matchedPosts : latestPosts).slice(0, 3);
  const sources = posts.map((post) => ({
    id: post.id,
    title: post.displayTitle,
    summary: post.summary,
    channel: post.channel
  }));

  let answer = local;
  if (!answer && matchedPosts.length) {
    answer = `我在树洞里找到 ${matchedPosts.length} 条相关讨论，可以先看这些内容：${matchedPosts
      .slice(0, 3)
      .map((post) => post.displayTitle)
      .join('、')}。`;
  }
  if (!answer) {
    answer = '暂时没有找到完全匹配的讨论。你可以换个关键词搜索，涉及教务、奖学金、考试等正式事项请以学校或学院通知为准。';
  }

  return {
    answer,
    sources,
    hint: sources.length ? `已引用 ${sources.length} 条树洞内容` : '无引用内容',
    digest: truncate(keyword, 24)
  };
};
