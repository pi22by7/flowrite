{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({config: {fontFallbackBaseUrl: 'font-fallbacks/'}});
if ('serviceWorker' in navigator && window.isSecureContext) {
  const registerOfflineCache = () => {
    navigator.serviceWorker.register('service-worker.js').catch(error => {
      console.warn('Offline cache is unavailable:', error);
    });
  };
  if (document.readyState === 'complete') registerOfflineCache();
  else window.addEventListener('load', registerOfflineCache, {once: true});
}
