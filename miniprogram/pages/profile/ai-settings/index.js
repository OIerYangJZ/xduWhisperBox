import { fetchAiModels, getAiConfig, saveAiConfig } from '../../../api/ai';
import { requireLoginPage } from '../../../utils/auth_guard';
import { applyThemeAndLanguage } from '../../../utils/theme_i18n';

const DEFAULT_KNOWLEDGE = [
  '西安电子科技大学简称西电，校区包括南校区和北校区。',
  '校园政策、校历、考试安排、奖助学金、宿舍管理等信息应以学校和学院官方通知为准。',
  '树洞帖子可以作为同学经验和近期讨论线索，涉及政策结论时需要提醒用户核对官方渠道。'
].join('\n\n');

Page({
  data: {
    form: {
      apiKey: '',
      baseUrl: '',
      model: '',
      knowledgeBase: '',
      includePosts: true
    },
    models: [],
    modelIndex: -1,
    loadingModels: false,
    saving: false
  },

  onShow() {
    applyThemeAndLanguage(this);
    if (!requireLoginPage()) return;
    applyThemeAndLanguage(this);
    this.loadConfig();
  },

  loadConfig() {
    const config = getAiConfig();
    const models = Array.isArray(config.models) ? config.models : [];
    const modelIndex = models.findIndex((item) => item === config.model);
    this.setData({
      form: {
        apiKey: config.apiKey || '',
        baseUrl: config.baseUrl || '',
        model: config.model || '',
        knowledgeBase: config.knowledgeBase || '',
        includePosts: config.includePosts !== false
      },
      models,
      modelIndex: modelIndex < 0 ? 0 : modelIndex
    }, () => {
      if (config.apiKey && config.baseUrl && models.length === 0) {
        this.loadModels();
      }
    });
  },

  onInput(event) {
    const key = event.currentTarget.dataset.key;
    if (!key) return;
    this.setData({ [`form.${key}`]: event.detail.value });
  },

  onIncludePostsChange(event) {
    this.setData({ 'form.includePosts': Boolean(event.detail.value) });
  },

  async loadModels() {
    const apiKey = this.data.form.apiKey.trim();
    const baseUrl = this.data.form.baseUrl.trim();
    if (!apiKey || !baseUrl) {
      wx.showToast({ title: '请先填写 Key 和 URL', icon: 'none' });
      return;
    }
    if (this.data.loadingModels) return;

    this.setData({ loadingModels: true });
    wx.showLoading({ title: '拉取模型中' });
    try {
      const models = await fetchAiModels({ apiKey, baseUrl });
      const model = models.includes(this.data.form.model)
        ? this.data.form.model
        : (models[0] || '');
      saveAiConfig({
        ...this.data.form,
        apiKey,
        baseUrl,
        model,
        models
      });
      this.setData({
        models,
        modelIndex: Math.max(0, models.findIndex((item) => item === model)),
        'form.model': model
      });
      wx.showToast({ title: models.length ? '已更新模型' : '未找到模型', icon: 'none' });
    } catch (error) {
      wx.showToast({ title: '拉取失败', icon: 'none' });
    } finally {
      wx.hideLoading();
      this.setData({ loadingModels: false });
    }
  },

  onModelChange(event) {
    const index = Number(event.detail.value);
    const model = this.data.models[index] || '';
    this.setData({
      modelIndex: index,
      'form.model': model
    });
  },

  useDefaultKnowledge() {
    this.setData({ 'form.knowledgeBase': DEFAULT_KNOWLEDGE });
  },

  saveConfig() {
    if (this.data.saving) return;
    const apiKey = this.data.form.apiKey.trim();
    const baseUrl = this.data.form.baseUrl.trim();
    const model = this.data.form.model.trim();
    if (!apiKey || !baseUrl || !model) {
      wx.showToast({ title: '请补全 Key、URL 和模型', icon: 'none' });
      return;
    }
    this.setData({ saving: true });
    saveAiConfig({
      ...this.data.form,
      apiKey,
      baseUrl,
      model,
      models: this.data.models
    });
    wx.showToast({ title: '已保存', icon: 'success' });
    this.setData({ saving: false });
  }
});
