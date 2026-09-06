import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { addCurtains } from './curtains.mjs';
import { addDetails, woodFloorTexture } from './details.mjs';
import { layout as L } from './layout.mjs';

const stage = document.getElementById('stage'), canvas = document.getElementById('scene');
const status = document.getElementById('status'), selection = document.getElementById('selection');
let renderer, controls, resizeObserver, disposed = false, active = true, pending = 0;
let scene, camera, curtainController, topView = false;
const pickables = [], labels = [], textures = [], wallGroup = new THREE.Group();
const center = new THREE.Vector3(L.room.width/2, .55, L.room.depth/2);
function fail(e) {
  status.hidden = false; status.textContent = '房间没能显示\n' + (e?.message || String(e));
  document.getElementById('retry').hidden = false;
}
window.addEventListener('error', e => fail(e.error || e.message));
window.addEventListener('unhandledrejection', e => fail(e.reason));
document.getElementById('retry').onclick = () => location.reload();
function render() {
  pending = 0;
  if (disposed || !active || document.hidden || !renderer) return;
  renderer.render(scene, camera);
}
function invalidate() {
  if (!pending && !disposed && active && !document.hidden) pending = requestAnimationFrame(render);
}
// No continuous render loop, no AI/network, no scene state written to a server.
window.alcoveRoom3D = {
  setActive(value) { active = Boolean(value); if (!active) curtainController?.reset(); if (!active && pending) {cancelAnimationFrame(pending);pending=0;} invalidate(); },
  dispose() {
    disposed = true; curtainController?.dispose(); cancelAnimationFrame(pending); resizeObserver?.disconnect(); controls?.dispose();
    const geometries = new Set(), materials = new Set();
    scene?.traverse(o => {if(o.geometry) geometries.add(o.geometry);if(o.material) (Array.isArray(o.material)?o.material:[o.material]).forEach(m=>materials.add(m));});
    geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());textures.forEach(t=>t.dispose());
    renderer?.dispose();renderer?.forceContextLoss();
  }
};
document.addEventListener('visibilitychange', () => { if(document.hidden) curtainController?.reset(); invalidate(); });
function mat(color, extra={}) {return new THREE.MeshStandardMaterial({color, roughness:.85,...extra});}
const wood = mat('#aa7851'), lightWood = mat('#c8a786'), cream = mat('#e4dcd0');
function box(parent, w,h,d,x,y,z, material, tag) {
 const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d), material);
 mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;
 if(tag){mesh.userData.description=tag;pickables.push(mesh);}
 parent.add(mesh);return mesh;
}
function label(text,x,y,z) {
 const c=document.createElement('canvas');c.width=384;c.height=96;
 const ctx=c.getContext('2d');ctx.fillStyle='rgba(255,250,242,.94)';ctx.fillRect(0,0,384,96);
 ctx.fillStyle='#372d29';ctx.font='500 42px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(text,192,48);
 const texture=new THREE.CanvasTexture(c);texture.colorSpace=THREE.SRGBColorSpace;textures.push(texture);
 const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,depthTest:false,transparent:true}));
 sprite.scale.set(.8,.2,1);sprite.position.set(x,y,z);sprite.renderOrder=10;scene.add(sprite);labels.push(sprite);
}
function makeScene() {
 scene=new THREE.Scene();
 renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'low-power'});
 renderer.setPixelRatio(Math.min(devicePixelRatio||1,2));renderer.shadowMap.enabled=true;
 renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.outputColorSpace=THREE.SRGBColorSpace;
 renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.25;
 camera=new THREE.PerspectiveCamera(38,1,.05,60);
 controls=new OrbitControls(camera,canvas);controls.target.copy(center);controls.enableDamping=false;
 controls.minDistance=2.6;controls.maxDistance=24;controls.maxPolarAngle=Math.PI*.485;
 controls.addEventListener('change',invalidate);
 scene.add(new THREE.HemisphereLight('#fff5e7','#a29385',2.4));
 const sun=new THREE.DirectionalLight('#fff4e8',3);sun.position.set(1,7,-3);sun.castShadow=true;
 sun.shadow.mapSize.set(1024,1024);Object.assign(sun.shadow.camera,{left:-4,right:4,top:4,bottom:-4,near:.1,far:20});sun.shadow.normalBias=.03;scene.add(sun);
 const floor=mat('#ffffff',{map:woodFloorTexture(textures)});
 box(scene,L.room.width,.12,L.room.depth,L.room.width/2,-.06,L.room.depth/2,floor);
 // Inexpensive plank seams rather than large texture maps.
 for(let x=.22;x<L.room.width;x+=.22) box(scene,.008,.002,L.room.depth,x,.002,L.room.depth/2,mat('#b0a99f'));
 scene.add(wallGroup);
 const wall=mat('#e4ddd4');
 box(wallGroup,.09,L.room.height,L.room.depth,-.045,L.room.height/2,L.room.depth/2,wall);
 const win=L.window;
 box(wallGroup,L.room.width,win.sill,.09,L.room.width/2,win.sill/2,-.045,wall);
 box(wallGroup,L.room.width,L.room.height-win.sill-win.height,.09,L.room.width/2,(L.room.height+win.sill+win.height)/2,-.045,wall);
 box(wallGroup,win.x,win.height,.09,win.x/2,win.sill+win.height/2,-.045,wall);
 box(wallGroup,L.room.width-win.x-win.width,win.height,.09,(L.room.width+win.x+win.width)/2,win.sill+win.height/2,-.045,wall);
 const frame=mat('#f3eee5'),glass=mat('#b9d4d6',{transparent:true,opacity:.55,side:THREE.DoubleSide});
 box(wallGroup,win.width,win.height,.018,win.x+win.width/2,win.sill+win.height/2,-.04,glass);
 for(const x of [win.x,win.x+win.width/2,win.x+win.width])box(wallGroup,.035,win.height,.07,x,win.sill+win.height/2,0,frame);
 for(const y of [win.sill,win.sill+win.height])box(wallGroup,win.width,.04,.07,win.x+win.width/2,y,0,frame);
 label('窗户',win.x+win.width/2,2.45,.03);
 addDetails({scene,L,box,label,textures,pickables});
 // Front/right walls omitted to expose the interior. Door footprint preserves sketch location.
 const door=L.door;box(scene,door.width,.015,.12,door.x+door.width/2,.015,L.room.depth-.06,mat('#776354'),'门口：图的右下方；宽度暂估，开门方向未确定。');
 label('门口',door.x+door.width/2,.25,L.room.depth-.1);
 const selectRay=new THREE.Raycaster(), pointer=new THREE.Vector2();let start=null;
 canvas.addEventListener('pointerdown',e=>{start={x:e.clientX,y:e.clientY,id:e.pointerId};});
 canvas.addEventListener('pointercancel',()=>{start=null;});
 canvas.addEventListener('pointerup',e=>{
  if(!start||e.pointerId!==start.id||Math.hypot(e.clientX-start.x,e.clientY-start.y)>8){start=null;return;}start=null;
  const r=canvas.getBoundingClientRect();pointer.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);
  selectRay.setFromCamera(pointer,camera);const hit=selectRay.intersectObjects(pickables,false)[0];
  if(hit)selection.textContent=hit.object.userData.description;
 });
 canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();if(!disposed)fail('图形资源被系统释放，请重新加载');});
 function resize(){renderer.setSize(stage.clientWidth,stage.clientHeight,false);camera.aspect=stage.clientWidth/Math.max(stage.clientHeight,1);camera.updateProjectionMatrix();view(topView);invalidate();}
 resizeObserver=new ResizeObserver(resize);resizeObserver.observe(stage);
 document.getElementById('perspective').onclick=()=>view(false);
 document.getElementById('top').onclick=()=>view(true);
 document.getElementById('walls').onclick=e=>{wallGroup.visible=!wallGroup.visible;e.currentTarget.setAttribute('aria-pressed',String(wallGroup.visible));invalidate();};
 document.getElementById('labels').onclick=e=>{const visible=!labels[0].visible;labels.forEach(l=>l.visible=visible);e.currentTarget.setAttribute('aria-pressed',String(visible));invalidate();};
 for(const [id,scale] of [['zoom-in',.82],['zoom-out',1.22]])document.getElementById(id).onclick=()=>{
  const offset=camera.position.clone().sub(controls.target);offset.setLength(THREE.MathUtils.clamp(offset.length()*scale,controls.minDistance,controls.maxDistance));camera.position.copy(controls.target).add(offset);controls.update();invalidate();
 };
 curtainController=addCurtains({scene,L,camera,canvas,controls,wallGroup,sun,textures,invalidate,selection});
 view(false);resize();status.hidden=true;
}
function view(top){
 topView = top;
 controls.target.copy(center);
 const halfFov = Math.atan(Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * Math.min(camera.aspect, 1));
 const distance = Math.min(23, 2.9 / Math.sin(halfFov));
 const direction = top ? new THREE.Vector3(0,1,.0001) : new THREE.Vector3(1,1.2,1.15).normalize();
 camera.position.copy(center).addScaledVector(direction,distance);
 camera.up.set(0,1,0);controls.update();
 document.getElementById('top').setAttribute('aria-pressed',String(top));
 document.getElementById('perspective').setAttribute('aria-pressed',String(!top));invalidate();
}
try{makeScene();}catch(e){fail(e);}
