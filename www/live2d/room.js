/* Local interactive model. No chat, credentials, AI or Electron bridge. */
(() => {
  const status = document.getElementById('status');
  const pause = document.getElementById('pause');
  const retry = document.getElementById('retry');
  const stage = document.getElementById('stage');
  let app, model, observer, touch, disposed = false, nativeActive = true;
  let tilt = 0;
  const feedback = document.getElementById("feedback");
  const tapButton = document.getElementById("tap"), strokeButton = document.getElementById("stroke");
  let paused = matchMedia('(prefers-reduced-motion: reduce)').matches;
  function fail(error) {
    if (disposed) return;
    status.hidden = false;
    status.textContent = '模型没有加载成功\n' + (error?.message || String(error));
    retry.hidden = false;
  }
  window.addEventListener('error', event => fail(event.error || event.message));
  window.addEventListener('unhandledrejection', event => fail(event.reason));
  retry.onclick = () => location.reload();
  function layout() {
    if (!app || !model || disposed) return;
    const w = Math.max(stage.clientWidth, 1), h = Math.max(stage.clientHeight, 1);
    app.renderer.resize(w, h);
    model.scale.set(1);
    const scale = Math.min(w * .92 / model.width, h * .96 / model.height);
    model.scale.set(scale);
    model.position.set(w / 2, h / 2);
    app.renderer.render(app.stage);
  }
  function updateActivity() {
    if (!app || !model || disposed) return;
    // autoUpdate is disabled: this application's ticker is the ONLY animation clock.
    if (nativeActive && !document.hidden && !paused) app.start(); else app.stop();
    if (paused || !nativeActive || document.hidden) touch?.reset();
    if (tapButton) tapButton.disabled = paused || !nativeActive;
    if (strokeButton) strokeButton.disabled = paused || !nativeActive;
    pause.textContent = paused ? '继续动作' : '暂停动作';
    pause.setAttribute('aria-pressed', String(paused));
  }
  window.alcoveLive2D = {
    setActive(active) { nativeActive = Boolean(active); updateActivity(); },
    dispose() {
      disposed = true;
      observer?.disconnect();
      touch?.dispose();
      app?.stop();
      app?.destroy(false, { children: true, texture: true, baseTexture: true });
      model = null; app = null;
    }
  };
  document.addEventListener('visibilitychange', updateActivity);
  pause.onclick = () => { paused = !paused; updateActivity(); };
  async function start() {
    try {
      if (!window.Live2DCubismCore || !window.PIXI?.live2d) throw new Error('缺少 Live2D 渲染文件');
      app = new PIXI.Application({ view: document.getElementById('model'), backgroundAlpha: 0,
        antialias: true, autoDensity: true, resolution: Math.min(devicePixelRatio || 1, 2),
        autoStart: false, sharedTicker: false, width: stage.clientWidth, height: stage.clientHeight });
      app.ticker.maxFPS = 30;
      const loaded = await PIXI.live2d.Live2DModel.from('model/hiyori_free_t08.model3.json', {
        autoInteract: false, autoUpdate: false
      });
      if (disposed) { loaded.destroy(); return; }
      model = loaded;
      model.anchor.set(.5, .5);
      app.stage.addChild(model);
      app.ticker.add(() => {
        if (!model) return;
        model.update(app.ticker.deltaMS);
        tilt *= Math.exp(-app.ticker.deltaMS / 180);
        model.rotation = tilt;
      });
      const canTouch = () => !!model && !disposed && nativeActive && !document.hidden && !paused;
      touch = window.createAlcoveTouch({
        element: stage, enabled: canTouch,
        point(event) {
          const rect = stage.getBoundingClientRect();
          const x = (event.clientX - rect.left) * stage.clientWidth / rect.width;
          const y = (event.clientY - rect.top) * stage.clientHeight / rect.height;
          const bounds = model.getBounds();
          const inside = x >= bounds.x && x <= bounds.x + bounds.width && y >= bounds.y && y <= bounds.y + bounds.height;
          model.focus(x, y);
          return { inside };
        },
        react(kind) {
          tilt = kind === 'stroke' ? .035 : -.02;
          // Use the model's actual bundled motions; no parallel core-parameter writer.
          Promise.resolve().then(() => disposed ? false : model.motion(kind === 'stroke' ? 'Flick' : 'Tap', 0, 3)).catch(error => {
            if (!disposed && feedback) feedback.textContent = '动作没加载成功：' + error.message;
          });
          if (feedback) feedback.textContent = kind === 'stroke' ? '摸摸～（仅本地动作）' : '戳了一下（仅本地动作）';
        }
      });
      if (tapButton) tapButton.onclick = () => touch.trigger('tap');
      if (strokeButton) strokeButton.onclick = () => touch.trigger('stroke');
      observer = new ResizeObserver(layout); observer.observe(stage);
      layout(); status.hidden = true; pause.disabled = false; updateActivity();
    } catch (error) { fail(error); }
  }
  start();
})();
