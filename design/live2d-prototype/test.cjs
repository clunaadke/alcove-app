const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../../www/live2d');
const source = fs.readFileSync(path.join(root, 'room.js'), 'utf8');
function harness({ reduced = false, missing = false, reject = false } = {}) {
  const elements = Object.fromEntries(['status','pause','retry','stage','model'].map(id => [id,
    { hidden:false, disabled:true, clientWidth:390, clientHeight:620, setAttribute() {} }]));
  const calls = {start:0,stop:0,destroy:0,render:0,observed:0};
  const events = {};
  const model = { width:1000, height:2000, scale:{set(){}}, position:{set(){}}, anchor:{set(){}}, update(){}, destroy(){} };
  class Application {
    constructor(options) { calls.options=options; this.ticker={add(fn){calls.tick=fn},deltaMS:33};this.renderer={resize(){},render(){calls.render++}};this.stage={addChild(){}}; }
    start(){calls.start++} stop(){calls.stop++} destroy(){calls.destroy++}
  }
  const PIXI = { Application, live2d:{Live2DModel:{from:async (_, opts) => {
    calls.modelOptions=opts; if(reject) throw new Error('test model failure'); return model;
  }}}};
  const context = { document:{hidden:false,getElementById:id=>elements[id],addEventListener:(e,f)=>events[e]=f},
    matchMedia:()=>({matches:reduced}), devicePixelRatio:3,
    location:{reload(){}}, ResizeObserver:class {observe(){calls.observed++}disconnect(){calls.observed--}},
    createAlcoveTouch:()=>({reset(){},dispose(){},trigger(){}}), PIXI, Live2DCubismCore:missing?null:{}, addEventListener(){} };
  context.window=context; vm.runInNewContext(source, context);
  return {context,elements,calls,events};
}
const settle = () => new Promise(resolve=>setImmediate(resolve));
test('all model and script references exist in packaged resources', () => {
 const model=JSON.parse(fs.readFileSync(path.join(root,'model/hiyori_free_t08.model3.json'))).FileReferences;
 const refs=[model.Moc,model.Physics,model.DisplayInfo,...model.Textures,...Object.values(model.Motions).flat().map(m=>m.File)];
 for(const ref of refs) assert.ok(fs.existsSync(path.join(root,'model',ref)),ref);
 const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
 for(const match of html.matchAll(/<script src="([^"]+)"/g)) assert.ok(fs.existsSync(path.join(root,match[1])),match[1]);
});
test('local renderer uses 30fps, bounded pixel ratio and no shared animation ticker', async()=>{
 const h=harness();await settle();
 assert.equal(h.calls.options.resolution,2);assert.equal(h.calls.options.sharedTicker,false);
 assert.equal(h.calls.modelOptions.autoUpdate,false);assert.equal(h.calls.modelOptions.autoInteract,false);
 assert.ok(h.calls.start>0);assert.equal(h.elements.status.hidden,true);
 h.context.alcoveLive2D.setActive(false);assert.ok(h.calls.stop>0);
 const starts=h.calls.start;h.context.document.hidden=true;h.context.alcoveLive2D.setActive(true);assert.equal(h.calls.start,starts);
 h.context.document.hidden=false;h.events.visibilitychange();assert.ok(h.calls.start>starts);
 h.elements.pause.onclick();assert.equal(h.elements.pause.textContent,'继续动作');
 h.context.alcoveLive2D.dispose();assert.equal(h.calls.destroy,1);assert.equal(h.calls.observed,0);
});
test('reduced motion starts paused but still renders a frame', async()=>{
 const h=harness({reduced:true});await settle();assert.equal(h.calls.start,0);assert.ok(h.calls.render>0);
});
test('missing runtime and rejected model show errors with retry', async()=>{
 for(const options of [{missing:true},{reject:true}]){const h=harness(options);await settle();assert.match(h.elements.status.textContent,/模型没有加载成功/);assert.equal(h.elements.retry.hidden,false);}
});
