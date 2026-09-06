/* Local gestures only. No network, AI/session or speech calls. */
(function (root) {
  root.createAlcoveTouch = function ({ element, enabled, point, react, now = () => performance.now() }) {
    let gesture = null, lastReaction = -Infinity;
    const pointers = new Set(), listeners = [];
    const on = (type, fn) => { element.addEventListener(type, fn); listeners.push([type, fn]); };
    function feedback(kind) {
      if (!enabled() || now() - lastReaction < 850) return false;
      lastReaction = now(); react(kind); return true;
    }
    on('pointerdown', e => {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      pointers.add(e.pointerId);
      if (pointers.size !== 1 || !enabled()) { gesture = null; return; }
      const p = point(e);
      if (!p?.inside) return;
      gesture = { id: e.pointerId, x: e.clientX, y: e.clientY, distance: 0, started: now(), rubbed: false };
      element.setPointerCapture?.(e.pointerId);
      e.preventDefault();
    });
    on('pointermove', e => {
      if (!gesture || gesture.id !== e.pointerId || !enabled()) return;
      point(e);
      gesture.distance += Math.hypot(e.clientX - gesture.x, e.clientY - gesture.y);
      gesture.x = e.clientX; gesture.y = e.clientY;
      if (gesture.distance > 24) { gesture.rubbed = true; feedback('stroke'); }
      e.preventDefault();
    });
    function finish(e, cancelled) {
      pointers.delete(e.pointerId);
      if (!gesture || gesture.id !== e.pointerId) return;
      if (!cancelled && !gesture.rubbed) feedback(now() - gesture.started > 450 ? 'stroke' : 'tap');
      gesture = null;
      if (element.hasPointerCapture?.(e.pointerId)) element.releasePointerCapture(e.pointerId);
    }
    on('pointerup', e => finish(e, false));
    on('pointercancel', e => finish(e, true));
    on('lostpointercapture', e => finish(e, true));
    return {
      trigger: feedback,
      reset() { gesture = null; pointers.clear(); },
      dispose() { gesture = null; pointers.clear(); listeners.forEach(([t,f]) => element.removeEventListener(t,f)); }
    };
  };
})(window);
