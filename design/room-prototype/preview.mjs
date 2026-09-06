// Exports the application's actual geometry and canvas textures to a CPU depth renderer.
// No Chromium, WebGL or iPhone emulation; lighting is deliberately simplified.
import {parseHTML} from 'linkedom';import {createCanvas} from '@napi-rs/canvas';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';import * as THREE from 'three';
const {window,document}=parseHTML(readFileSync(new URL('../../www/room3d/index.html',import.meta.url),'utf8'));
Object.assign(globalThis,{window,document,devicePixelRatio:1,requestAnimationFrame:()=>0,cancelAnimationFrame:()=>{},ResizeObserver:class{observe(){}disconnect(){}}});
const stage=document.getElementById('stage');Object.defineProperties(stage,{clientWidth:{value:1100},clientHeight:{value:1000}});
const create=document.createElement.bind(document);document.createElement=tag=>tag==='canvas'?createCanvas(512,512):create(tag);
let source=readFileSync(new URL('./room.mjs',import.meta.url),'utf8');
source=source.replace("import { OrbitControls } from 'three/addons/controls/OrbitControls.js';",'class OrbitControls {constructor(){this.target=new THREE.Vector3()}addEventListener(){}update(){camera.lookAt(this.target);camera.updateMatrixWorld()}dispose(){}}');
source=source.replace("renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'low-power'});",'renderer={shadowMap:{},setPixelRatio(){},setSize(){},render(){},dispose(){},forceContextLoss(){}};');
source+=`\nif(!status.hidden) throw new Error(status.textContent);\nlabels.forEach(l=>scene.remove(l));\nfor(const [name,top] of [['perspective',false],['top',true]]){view(top);wallGroup.visible=!top;globalThis.capture(name,scene,camera);}`;
let materialsSeen=0;
globalThis.capture=(name,scene,camera)=>{
 scene.updateMatrixWorld(true);camera.updateMatrixWorld(true);const tris=[],maps=new Map();
 scene.traverse(o=>{
  if(!o.isMesh)return;let v=o;while(v){if(!v.visible)return;v=v.parent;}
  const g=o.geometry,pos=g.attributes.position,index=g.index,uv=g.attributes.uv,material=o.material;
  if(Array.isArray(material))throw new Error('preview requires one material per mesh');
  let map=null;
  if(material.map&&uv){const t=material.map;if(!maps.has(t)){const id=maps.size;maps.set(t,id);writeFileSync(`/tmp/room-${name}-texture-${id}.png`,t.image.toBuffer('image/png'));}map={id:maps.get(t),repeat:[t.repeat.x,t.repeat.y],flipY:t.flipY};}
  const count=index?index.count:pos.count;
  for(let i=0;i<count;i+=3){
   const ids=[0,1,2].map(k=>index?index.getX(i+k):i+k);
   const pts=ids.map(j=>new THREE.Vector3(pos.getX(j),pos.getY(j),pos.getZ(j)).applyMatrix4(o.matrixWorld));
   const normal=pts[1].clone().sub(pts[0]).cross(pts[2].clone().sub(pts[0])).normalize();
   const light=new THREE.Vector3(-.3,1,.5).normalize();const shade=.78+.22*Math.max(0,normal.dot(light));
   const color=material.color.clone().convertLinearToSRGB();
   const projected=pts.map(p=>{const clip=new THREE.Vector4(p.x,p.y,p.z,1).applyMatrix4(camera.matrixWorldInverse).applyMatrix4(camera.projectionMatrix);return [(clip.x/clip.w+1)*550,(1-clip.y/clip.w)*500,clip.z/clip.w,1/clip.w];});
   tris.push({p:projected,c:[color.r,color.g,color.b].map(v=>v*shade*255),opacity:material.opacity,alphaTest:material.alphaTest,map,uv:map?ids.map(j=>[uv.getX(j),uv.getY(j)]):null});
  }
 });
 writeFileSync('/tmp/alcove-room-'+name+'.json',JSON.stringify(tris));console.log(name, tris.length,'triangles',maps.size,'textures');
};
const generated=new URL('./.preview-generated.mjs',import.meta.url);writeFileSync(generated,source);
try{await import(generated.href+'?'+Date.now());}finally{unlinkSync(generated);}
