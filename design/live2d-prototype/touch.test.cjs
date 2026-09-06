const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../www/live2d/touch.js'),'utf8');
function setup(){let time=0,enabled=true;const handlers={},calls=[];const window={};vm.runInNewContext(source,{window});
 const element={addEventListener:(n,f)=>handlers[n]=f,removeEventListener:n=>delete handlers[n],setPointerCapture(){},hasPointerCapture:()=>false};
 const c=window.createAlcoveTouch({element,enabled:()=>enabled,point:e=>({inside:e.clientX<100}),react:x=>calls.push(x),now:()=>time});
 const emit=(type,x=10,id=1)=>handlers[type]({pointerId:id,clientX:x,clientY:10,pointerType:'touch',preventDefault(){}});
 return {calls,c,emit,handlers,advance:n=>time+=n,disable:()=>enabled=false};}
test('tap and long press use separate local feedback',()=>{const h=setup();h.emit('pointerdown');h.emit('pointerup');h.advance(1000);h.emit('pointerdown');h.advance(500);h.emit('pointerup');assert.deepEqual(h.calls,['tap','stroke']);});
test('rubbing is rate limited and does not add a tap on release',()=>{const h=setup();h.emit('pointerdown');h.emit('pointermove',50);h.emit('pointermove',10);h.emit('pointermove',60);h.emit('pointerup');assert.deepEqual(h.calls,['stroke']);});
test('background, outside model and cancellation do not trigger actions',()=>{const h=setup();h.emit('pointerdown',200);h.emit('pointerup',200);h.emit('pointerdown');h.emit('pointercancel');h.disable();h.emit('pointerdown');h.emit('pointerup');assert.equal(h.calls.length,0);});
test('multi touch cancels a gesture and disposal removes listeners',()=>{const h=setup();h.emit('pointerdown');h.emit('pointerdown',10,2);h.emit('pointerup');h.emit('pointerup',10,2);assert.equal(h.calls.length,0);h.c.dispose();assert.equal(Object.keys(h.handlers).length,0);});
