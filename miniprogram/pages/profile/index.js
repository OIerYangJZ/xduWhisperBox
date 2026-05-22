import { getUserInfo } from '../../api/auth';
import { getFavoritePosts, togglePostLike } from '../../api/posts';
import {
  getFollowers,
  getFollowing,
  getMyComments,
  getMyPosts
} from '../../api/user';
import { avatarInitial, resolveUrl } from '../../utils/format';
import { requireLoginPage } from '../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../utils/theme_i18n';

const TABS = [
  { key: 'posts', label: '帖子' },
  { key: 'favorites', label: '收藏' },
  { key: 'activities', label: '动态' }
];

const buildProfile = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || '';
  return {
    ...raw,
    nickname,
    avatarInitial: avatarInitial(nickname || '匿名同学'),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    backgroundImageUrl: resolveUrl(raw.backgroundImageUrl || '')
  };
};

const buildFollowUser = (raw = {}) => {
  const nickname = raw.nickname || raw.alias || raw.name || '西电同学';
  return {
    ...raw,
    id: String(raw.id || raw.userId || ''),
    nickname,
    avatarInitial: avatarInitial(nickname),
    avatarUrl: resolveUrl(raw.avatarUrl || ''),
    isMutual: Boolean(raw.isFollowing && raw.isFollower)
  };
};

const buildPost = (raw = {}) => {
  const imageUrls = Array.isArray(raw.imageUrls)
    ? raw.imageUrls
    : Array.isArray(raw.images)
      ? raw.images
      : [];
  return {
    ...raw,
    id: String(raw.id || raw.postId || ''),
    imageUrls: imageUrls.map(resolveUrl).filter(Boolean),
    liked: Boolean(raw.liked || raw.isLiked),
    isLiked: Boolean(raw.liked || raw.isLiked),
    likeCount: Number(raw.likeCount || 0),
    commentCount: Number(raw.commentCount || 0)
  };
};

Page({
  data: {
    tabs: TABS,
    activeTab: 'posts',
    userInfo: null,
    followers: [],
    following: [],
    posts: [],
    favoritePosts: [],
    comments: [],
    loadingProfile: true,
    loadingPosts: true,
    loadingFavorites: true,
    loadingComments: true,
    showFollowSheet: false,
    followSheetTitle: '',
    followSheetUsers: [],
    followSheetMutualUsers: [],
    followSheetOtherUsers: []
  },

  onLoad() {
    this._tabScrollTops = { posts: 0, favorites: 0, activities: 0 };
    this._didInitialShow = false;
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    this.loadInitialData();
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    if (!this._didInitialShow) {
      this._didInitialShow = true;
      return;
    }
    this.refreshProfile();
  },

  onPullDownRefresh() {
    this.refreshAll().finally(() => wx.stopPullDownRefresh());
  },

  onPageScroll(event) {
    if (!this._tabScrollTops) return;
    this._tabScrollTops[this.data.activeTab] = event.scrollTop || 0;
  },

  loadInitialData() {
    this.refreshProfile();
    this.loadPosts();
    this.loadFavorites();
    this.loadComments();
  },

  refreshAll() {
    return Promise.all([
      this.refreshProfile(),
      this.loadPosts(),
      this.loadFavorites(),
      this.loadComments()
    ]);
  },

  async refreshProfile() {
    this.setData({ loadingProfile: true });
    const [profileResponse, followers, following] = await Promise.all([
      getUserInfo(),
      getFollowers(),
      getFollowing()
    ]);
    this.setData({
      userInfo: buildProfile(profileResponse.data),
      followers: followers.map(buildFollowUser),
      following: following.map(buildFollowUser),
      loadingProfile: false
    });
  },

  async loadPosts() {
    this.setData({ loadingPosts: true });
    const posts = await getMyPosts();
    this.setData({
      posts: posts.map(buildPost),
      loadingPosts: false
    });
  },

  async loadFavorites() {
    this.setData({ loadingFavorites: true });
    const posts = await getFavoritePosts();
    this.setData({
      favoritePosts: posts.map(buildPost),
      loadingFavorites: false
    });
  },

  async loadComments() {
    this.setData({ loadingComments: true });
    const comments = await getMyComments();
    this.setData({
      comments: comments.map((item = {}) => ({
        ...item,
        id: String(item.id || item.commentId || ''),
        postId: String(item.postId || ''),
        postTitle: item.postTitle || '原帖',
        content: item.content || '',
        timeText: item.timeText || ''
      })),
      loadingComments: false
    });
  },

  switchProfileTab(event) {
    const tab = event.currentTarget.dataset.tab;
    if (!tab || tab === this.data.activeTab) return;
    this._tabScrollTops[this.data.activeTab] = this._tabScrollTops[this.data.activeTab] || 0;
    this.setData({ activeTab: tab }, () => {
      wx.pageScrollTo({
        scrollTop: this._tabScrollTops[tab] || 0,
        duration: 0
      });
    });
  },

  goToEditProfile() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/edit-profile/index' });
  },

  goToSettings() {
    if (!requireLoginPage()) return;
    wx.navigateTo({ url: '/pages/profile/settings/index' });
  },

  openFollowSheet(event) {
    const type = event.currentTarget.dataset.type;
    const users = type === 'following' ? this.data.following : this.data.followers;
    const title = type === 'following' ? '关注' : '粉丝';
    const mutual = users.filter((item) => item.isMutual);
    const others = users.filter((item) => !item.isMutual);
    this.setData({
      showFollowSheet: true,
      followSheetTitle: title,
      followSheetUsers: users,
      followSheetMutualUsers: mutual,
      followSheetOtherUsers: others
    });
  },

  closeFollowSheet() {
    this.setData({
      showFollowSheet: false,
      followSheetTitle: '',
      followSheetUsers: [],
      followSheetMutualUsers: [],
      followSheetOtherUsers: []
    });
  },

  stopTouchMove() {},

  goPostDetail(event) {
    const id = event.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/campus/post-detail/index?id=${id}` });
  },

  openCommentDetail(event) {
    const postId = event.currentTarget.dataset.postId;
    const commentId = event.currentTarget.dataset.commentId;
    if (!postId) return;
    wx.navigateTo({
      url: `/pages/campus/post-detail/index?id=${postId}${commentId ? `&commentId=${commentId}` : ''}`
    });
  },

  async toggleLike(event) {
    const source = event.currentTarget.dataset.source;
    const index = Number(event.currentTarget.dataset.index);
    const key = source === 'favorites' ? 'favoritePosts' : 'posts';
    const posts = this.data[key].slice();
    const post = posts[index];
    if (!post || !post.id) return;
    const before = Boolean(post.liked || post.isLiked);
    const result = await togglePostLike(post.id);
    const liked = Boolean(result.liked);
    const delta = liked === before ? 0 : liked ? 1 : -1;
    posts[index] = {
      ...post,
      liked,
      isLiked: liked,
      likeCount: Math.max(0, Number(post.likeCount || 0) + delta)
    };
    this.setData({ [key]: posts });
  },

  previewPostImage(event) {
    const source = event.currentTarget.dataset.source;
    const postIndex = Number(event.currentTarget.dataset.postIndex);
    const current = event.currentTarget.dataset.url;
    const posts = source === 'favorites' ? this.data.favoritePosts : this.data.posts;
    const post = posts[postIndex];
    const urls = (post && post.imageUrls) || [];
    if (current && urls.length) {
      wx.previewImage({ current, urls });
    }
  },

  showShareToast() {
    wx.showToast({ title: '链接已复制', icon: 'none', duration: 1000 });
  }
});
