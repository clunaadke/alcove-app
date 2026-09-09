// Node event/RAF check: real OrbitControls and scene code, stub GPU only.
import {parseHTML} from 'linkedom';import {createCanvas,loadImage} from '@napi-rs/canvas';import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';import assert from 'node:assert/strict';
const {window,document}=parseHTML(readFileSync(new URL('../../www/room3d/index.html',import.meta.url),'utf8'));
let next=1,frames=0;const queue=new Map();
Object.assign(globalThis,{window,document,self:globalThis,devicePixelRatio:1,requestAnimationFrame:fn=>{const id=next++;queue.set(id,fn);return id;},cancelAnimationFrame:id=>queue.delete(id),ResizeObserver:class{observe(){}disconnect(){}},createImageBitmap:async blob=>{const i=await loadImage(Buffer.from(await blob.arrayBuffer()));const c=createCanvas(i.width,i.height);c.getContext('2d').drawImage(i,0,0);return c;}});
const stage=document.getElementById('stage'),canvas=document.getElementById('scene');
for(const el of [stage,canvas]){Object.defineProperties(el,{clientWidth:{value:390},clientHeight:{value:480}});el.getBoundingClientRect=()=>({left:0,top:0,width:390,height:480});}
canvas.setPointerCapture=()=>{};canvas.releasePointerCapture=()=>{};canvas.hasPointerCapture=()=>false;
const create=document.createElement.bind(document);document.createElement=tag=>tag==='canvas'?createCanvas(512,512):create(tag);
globalThis.gpuFrame=()=>frames++;
let source=readFileSync(new URL('./room.mjs',import.meta.url),'utf8').replace("renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'low-power'});",'renderer={shadowMap:{},setPixelRatio(){},setSize(){},render(){globalThis.gpuFrame()},dispose(){},forceContextLoss(){}};');
source+='\nawait beddingReady;globalThis.probe={camera,controls,getActive:()=>active};if(!status.hidden)throw new Error(status.textContent);';
const tmp=new URL('./.interaction-generated.mjs',import.meta.url);writeFileSync(tmp,source);try{await import(tmp.href);}finally{unlinkSync(tmp);}
function flush(){const q=[...queue.values()];queue.clear();q.forEach(f=>f());}
flush();assert.ok(frames>0);let n=frames;document.getElementById('top').onclick();flush();assert.ok(frames>n);console.log('PASS top button schedules and renders another frame');
document.getElementById('perspective').onclick();flush();const before=probe.camera.position.clone();
function pointer(type,x,y){const e=new window.Event(type,{bubbles:true,cancelable:true});Object.assign(e,{pointerId:1,pointerType:'touch',clientX:x,clientY:y,pageX:x,pageY:y,button:0,buttons:1});canvas.dispatchEvent(e);}
pointer('pointerdown',300,390);pointer('pointermove',210,410);pointer('pointerup',210,410);flush();assert.ok(before.distanceTo(probe.camera.position)>.01);console.log('PASS touch drag through real OrbitControls changes camera');
window.alcoveRoom3D.setActive(false);n=frames;document.getElementById('top').onclick();flush();assert.equal(frames,n);console.log('PASS inactive state reproduces frozen canvas despite button handler');window.alcoveRoom3D.setActive(true);flush();assert.ok(frames>n);console.log('PASS reactivation renders again');window.alcoveRoom3D.dispose();
