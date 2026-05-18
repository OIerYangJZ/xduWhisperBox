{{flutter_js}}
{{flutter_build_config}}

const xduBootUpdateStatus =
  typeof window !== 'undefined' ? window.xduBootUpdateStatus : null;
const xduBootHide =
  typeof window !== 'undefined' ? window.xduBootHide : null;
const xduBootFail =
  typeof window !== 'undefined' ? window.xduBootFail : null;

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      if (typeof xduBootUpdateStatus === 'function') {
        xduBootUpdateStatus('正在初始化渲染引擎...');
      }
      const appRunner = await engineInitializer.initializeEngine();
      if (typeof xduBootUpdateStatus === 'function') {
        xduBootUpdateStatus('正在进入首页...');
      }
      await appRunner.runApp();
      if (typeof xduBootHide === 'function') {
        window.setTimeout(() => xduBootHide(), 120);
      }
    } catch (error) {
      console.error(error);
      if (typeof xduBootFail === 'function') {
        xduBootFail(
          error?.message || '应用启动失败，请稍后刷新重试。',
        );
      }
    }
  },
});
