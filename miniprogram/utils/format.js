import { baseUrl } from '../config/env';

export const DEFAULT_CHANNELS = [
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
  '其他'
];

export const getData = (response, fallback = null) => {
  if (response && Object.prototype.hasOwnProperty.call(response, 'data')) {
    return response.data;
  }
  return response || fallback;
};

export const toArray = (value) => {
  return Array.isArray(value) ? value : [];
};

export const truncate = (value, max = 80) => {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max)}...`;
};

export const formatTime = (value) => {
  const text = String(value || '').trim();
  const date = text ? new Date(text) : null;
  if (!date || Number.isNaN(date.getTime())) return '';

  const diff = Date.now() - date.getTime();
  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (diff >= 0 && diff < 5 * minute) return 'now';
  if (diff >= 0 && diff < hour) return `${Math.floor(diff / minute)}min`;
  if (diff >= 0 && diff < day) return `${Math.floor(diff / hour)}h`;
  if (diff >= 0 && diff < 7 * day) return `${Math.floor(diff / day)}d`;

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
};

const CHANNEL_COLORS = {
  全部: '#8E8E93',
  综合: '#6B7FD7',
  学习交流: '#5E8FD4',
  二手交易: '#5EAF7C',
  找搭子: '#E09C5E',
  失物招领: '#D45E8A',
  吐槽日常: '#9B6ED4',
  求助问答: '#5EAAD4',
  活动拼车: '#E06C4E',
  找对象: '#D45E8A',
  交友扩列: '#5EC4AF',
  八卦吃瓜: '#9B6ED4',
  其他: '#6B7FD7'
};

export const channelColor = (channel) => {
  return CHANNEL_COLORS[String(channel || '').trim()] || '#155E75';
};

export const avatarInitial = (value) => {
  const text = String(value || '').trim();
  if (!text) return '匿';
  return text.slice(0, 1);
};

export const resolveUrl = (value) => {
  const text = String(value || '').trim();
  if (!text) return '';
  if (/^https?:\/\//i.test(text)) return text;
  if (text.startsWith('/')) return `${baseUrl}${text}`;
  return `${baseUrl.replace(/\/$/, '')}/${text}`;
};

const statusLabel = (status) => {
  const value = String(status || '').toLowerCase();
  if (value === 'resolved') return '已解决';
  if (value === 'closed') return '已结束';
  return '进行中';
};

export const normalizePost = (raw = {}) => {
  const title = String(raw.title || '').trim();
  const content = String(raw.content || '').trim();
  const tags = toArray(raw.tags).map((item) => String(item || '').trim()).filter(Boolean);
  const rawImageUrls = toArray(raw.imageUrls);
  const sourceImageUrls = rawImageUrls.length ? rawImageUrls : toArray(raw.images);
  const imageUrls = sourceImageUrls.map(resolveUrl).filter(Boolean);
  const displayTitle = title || truncate(content, 24) || '无标题帖子';
  const isAnonymous = Boolean(raw.isAnonymous || raw.useAnonymousAlias);
  const authorAlias = isAnonymous
    ? String(raw.authorAlias || raw.alias || raw.authorName || '匿名用户')
    : String(raw.authorAlias || raw.alias || raw.authorName || '匿名同学');
  const channel = String(raw.channel || raw.channelName || '综合');
  const displayChannel = channel === '其他' ? '综合' : channel;
  return {
    ...raw,
    id: String(raw.id || raw.postId || ''),
    title,
    displayTitle,
    content,
    summary: truncate(content, 96),
    channel,
    displayChannel,
    channelColor: channelColor(channel),
    tags,
    tagText: tags.join(' / '),
    authorAlias,
    authorInitial: isAnonymous ? '匿' : avatarInitial(authorAlias),
    authorAvatarUrl: isAnonymous ? '' : resolveUrl(raw.authorAvatarUrl || ''),
    isAnonymous,
    createdAt: raw.createdAt || '',
    timeText: formatTime(raw.createdAt),
    likeCount: Number(raw.likeCount || 0),
    commentCount: Number(raw.commentCount || 0),
    favoriteCount: Number(raw.favoriteCount || 0),
    viewCount: Number(raw.viewCount || 0),
    liked: Boolean(raw.liked || raw.isLiked),
    favorited: Boolean(raw.favorited || raw.isFavorited),
    isPinned: Boolean(raw.isPinned),
    statusLabel: statusLabel(raw.status),
    imageUrls,
    firstImageUrl: imageUrls[0] || ''
  };
};

export const normalizeComment = (raw = {}) => {
  const authorAlias = String(raw.authorAlias || raw.authorName || '匿名同学');
  return {
    ...raw,
    id: String(raw.id || raw.commentId || ''),
    content: String(raw.content || ''),
    authorAlias,
    authorInitial: avatarInitial(authorAlias),
    authorAvatarUrl: resolveUrl(raw.authorAvatarUrl || raw.authorAvatar || ''),
    timeText: formatTime(raw.createdAt),
    likeCount: Number(raw.likeCount || 0),
    liked: Boolean(raw.liked || raw.isLiked),
    parentId: String(raw.parentId || '')
  };
};

export const normalizeNotification = (raw = {}) => {
  return {
    ...raw,
    id: String(raw.id || ''),
    title: String(raw.title || '通知'),
    content: String(raw.content || ''),
    type: String(raw.type || raw.notificationType || ''),
    timeText: formatTime(raw.createdAt),
    isRead: Boolean(raw.isRead),
    actorAvatarUrl: resolveUrl(raw.actorAvatarUrl || '')
  };
};
