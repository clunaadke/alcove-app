import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import beddingData from './bedding-data.mjs';
import { addWindowFoliage } from './foliage.mjs';
import { daylightAt } from './daylight-state.mjs';
import { addCurtains } from './curtains.mjs';
import { addDetails, woodFloorTexture } from './details.mjs';
import { layout as L } from './layout.mjs';

const stage = document.getElementById('stage'), canvas = document.getElementById('scene');
const status = document.getElementById('status'), selection = document.getElementById('selection');
let renderer, controls, resizeObserver, disposed = false, active = true, pending = 0;
let scene, camera, curtainController, topView = false;
let beddingReady=Promise.resolve();
const diagnostic=document.getElementById('interaction-diagnostic');
let touchCount=0,frameCount=0;
function reportInteraction(){if(diagnostic)diagnostic.textContent=`触摸 ${touchCount} · 刷新 ${frameCount} · ${disposed?'已释放':active?'启用':'暂停'} · ${document.hidden?'网页后台':'网页可见'}`;}
document.addEventListener('pointerdown',()=>{touchCount++;reportInteraction();},true);
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
  renderer.render(scene, camera);frameCount++;reportInteraction();
}
function invalidate() {
  if (!pending && !disposed && active && !document.hidden) pending = requestAnimationFrame(render);
}
// No continuous render loop, no AI/network, no scene state written to a server.
window.alcoveRoom3D = {
  setActive(value) { active = Boolean(value);reportInteraction(); if (!active) curtainController?.reset(); if (!active && pending) {cancelAnimationFrame(pending);pending=0;} invalidate(); },
  dispose() {
    disposed = true;reportInteraction(); curtainController?.dispose(); cancelAnimationFrame(pending); resizeObserver?.disconnect(); controls?.dispose();
    const geometries = new Set(), materials = new Set();
    scene?.traverse(o => {if(o.geometry) geometries.add(o.geometry);if(o.material) (Array.isArray(o.material)?o.material:[o.material]).forEach(m=>materials.add(m));});
    geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());textures.forEach(t=>t.dispose());
    renderer?.dispose();renderer?.forceContextLoss();
  }
};
document.addEventListener('visibilitychange', () => { reportInteraction(); if(document.hidden) curtainController?.reset(); invalidate(); });
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
 renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.10;
 camera=new THREE.PerspectiveCamera(38,1,.05,60);
 controls=new OrbitControls(camera,canvas);controls.target.copy(center);controls.enableDamping=false;
 controls.minDistance=2.6;controls.maxDistance=24;controls.maxPolarAngle=Math.PI*.485;
 controls.addEventListener('change',invalidate);
 const ambient=new THREE.HemisphereLight('#fff5e7','#a29385',1.2);scene.add(ambient);
 const sun=new THREE.DirectionalLight('#fff4e8',3);sun.position.set(1,7,-3);sun.castShadow=true;
 sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-4,right:4,top:4,bottom:-4,near:.1,far:20});sun.shadow.normalBias=.03;scene.add(sun);sun.target.position.set(.9,.45,1.2);scene.add(sun.target);
 const foliage=addWindowFoliage(scene);
 const treeToggle=document.getElementById('tree-shadow');
 treeToggle.onchange=()=>{foliage.visible=treeToggle.checked;invalidate();};
 const floor=mat('#ffffff',{map:woodFloorTexture(textures)});
 box(scene,L.room.width,.12,L.room.depth,L.room.width/2,-.06,L.room.depth/2,floor);
 // Inexpensive plank seams rather than large texture maps.
 for(let x=.22;x<L.room.width;x+=.22) box(scene,.008,.002,L.room.depth,x,.002,L.room.depth/2,mat('#49362e'));
 scene.add(wallGroup);
 const wall=mat('#eeedeb');
 box(wallGroup,.09,L.room.height,L.room.depth,-.045,L.room.height/2,L.room.depth/2,wall);
 const win=L.window;
 box(wallGroup,L.room.width,win.sill,.09,L.room.width/2,win.sill/2,-.045,wall);
 box(wallGroup,L.room.width,L.room.height-win.sill-win.height,.09,L.room.width/2,(L.room.height+win.sill+win.height)/2,-.045,wall);
 box(wallGroup,win.x,win.height,.09,win.x/2,win.sill+win.height/2,-.045,wall);
 box(wallGroup,L.room.width-win.x-win.width,win.height,.09,(L.room.width+win.x+win.width)/2,win.sill+win.height/2,-.045,wall);
 const frame=mat('#f3eee5'),glass=mat('#b9d4d6',{transparent:true,opacity:.12,side:THREE.DoubleSide});
 box(wallGroup,win.width,win.height,.018,win.x+win.width/2,win.sill+win.height/2,-.04,glass).castShadow=false;
 for(const x of [win.x,win.x+win.width/2,win.x+win.width])box(wallGroup,.035,win.height,.07,x,win.sill+win.height/2,0,frame);
 for(const y of [win.sill,win.sill+win.height])box(wallGroup,win.width,.04,.07,win.x+win.width/2,y,0,frame);
 label('窗户',win.x+win.width/2,2.45,.03);
 const furniture=addDetails({scene,L,box,label,textures,pickables});
 beddingReady=new GLTFLoader().parseAsync(Uint8Array.from(atob(beddingData),c=>c.charCodeAt(0)).buffer,'').then(gltf=>{
  gltf.scene.traverse(o=>{if(!o.isMesh)return;o.castShadow=true;o.receiveShadow=true;
   for(const m of (Array.isArray(o.material)?o.material:[o.material]))for(const value of Object.values(m))if(value?.isTexture){if(disposed)value.dispose();else textures.push(value);}
   if(disposed){o.geometry.dispose();for(const m of (Array.isArray(o.material)?o.material:[o.material]))m.dispose();}
  });
  if(disposed)return;
  const curtainAsset=gltf.scene.getObjectByName('CurtainPanelAsset');
  if(curtainAsset){curtainAsset.removeFromParent();curtainController.setPanelAsset(curtainAsset.geometry,curtainAsset.material);}
  scene.add(gltf.scene);furniture.beddingFallback.visible=false;invalidate();
 }).catch(e=>{if(!disposed)selection.textContent='精细床品加载失败，暂用基础床品：'+e.message;});
 for(const key of ['wardrobe','shelf']){
  const toggle=document.getElementById(key+'-visible');toggle.checked=furniture[key].visible;
  toggle.onchange=()=>{furniture[key].visible=toggle.checked;invalidate();};
 }
 // Front/right walls omitted to expose the interior. Door footprint preserves sketch location.
 const door=L.door;box(scene,door.width,.015,.12,door.x+door.width/2,.015,L.room.depth-.06,mat('#776354'),'门口：图的右下方；宽度暂估，开门方向未确定。');
 label('门口',door.x+door.width/2,.25,L.room.depth-.1);
 const selectRay=new THREE.Raycaster(), pointer=new THREE.Vector2();let start=null;
 canvas.addEventListener('pointerdown',e=>{start={x:e.clientX,y:e.clientY,id:e.pointerId};});
 canvas.addEventListener('pointercancel',()=>{start=null;});
 canvas.addEventListener('pointerup',e=>{
  if(!start||e.pointerId!==start.id||Math.hypot(e.clientX-start.x,e.clientY-start.y)>8){start=null;return;}start=null;
  const r=canvas.getBoundingClientRect();pointer.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);
  selectRay.setFromCamera(pointer,camera);const hit=selectRay.intersectObjects(pickables.filter(o=>{for(let p=o;p;p=p.parent)if(!p.visible)return false;return true;}),false)[0];
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
 let hour=14,curtainOpen=.8;
 const timeSlider=document.getElementById('sun-time'),timeLabel=document.getElementById('sun-label');
 function applyDaylight(){const d=daylightAt(hour,curtainOpen);sun.position.set(...d.position);sun.color.setRGB(...d.color);sun.intensity=d.intensity;ambient.intensity=d.ambient;timeLabel.textContent=d.label;invalidate();}
 timeSlider.oninput=()=>{hour=Number(timeSlider.value);applyDaylight();};
 curtainController=addCurtains({scene,L,camera,canvas,controls,wallGroup,sun,textures,invalidate,selection,onOpenness:value=>{curtainOpen=value;applyDaylight();}});
 applyDaylight();
 view(false);resize();status.hidden=true;reportInteraction();
}
function view(top){
 topView = top;
 controls.target.copy(center);
 const halfFov = Math.atan(Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * Math.min(camera.aspect, 1));
 const radius=Math.hypot(L.room.width/2,L.room.depth/2,L.room.height-center.y)+.12;
 const distance = Math.min(23, radius / Math.sin(halfFov));
 const direction = top ? new THREE.Vector3(0,1,.0001) : new THREE.Vector3(1,1.2,1.15).normalize();
 camera.position.copy(center).addScaledVector(direction,distance);
 camera.up.set(0,1,0);controls.update();
 document.getElementById('top').setAttribute('aria-pressed',String(top));
 document.getElementById('perspective').setAttribute('aria-pressed',String(!top));invalidate();
}
try{makeScene();}catch(e){fail(e);}
