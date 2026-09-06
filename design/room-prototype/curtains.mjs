import * as THREE from 'three';
import { curtainWidth, dragOpenness } from './curtain-state.mjs';
export function addCurtains({scene,L,camera,canvas,controls,wallGroup,sun,textures,invalidate,selection}){
 const root=new THREE.Group();wallGroup.add(root);const panels=[],interactive=[];let openness=.8,drag=null;
 const w=L.window,fullWidth=w.width/2+.1,top=w.sill+w.height+.08,height=1.57;
 const cloth=new THREE.MeshStandardMaterial({color:'#e7e0d2',roughness:1,side:THREE.DoubleSide});
 // Transparent lace texture is generated locally; no personal photo or external asset.
 const tile=document.createElement('canvas');tile.width=256;tile.height=128;const ctx=tile.getContext('2d');ctx.clearRect(0,0,256,128);
 ctx.strokeStyle='#f9f5e9';ctx.lineWidth=4;
 for(let i=0;i<8;i++){
  const x=i*32+16;ctx.beginPath();ctx.ellipse(x,57,14,45,0,0,Math.PI*2);ctx.stroke();
  ctx.beginPath();ctx.arc(x,20,6,0,Math.PI*2);ctx.stroke();
 }
 const tex=new THREE.CanvasTexture(tile);tex.colorSpace=THREE.SRGBColorSpace;tex.wrapS=THREE.RepeatWrapping;tex.repeat.set(3,1);textures.push(tex);
 const lace=new THREE.MeshStandardMaterial({map:tex,transparent:true,alphaTest:.2,side:THREE.DoubleSide,roughness:1});
 const rod=new THREE.Mesh(new THREE.CylinderGeometry(.012,.012,w.width+.3,16),new THREE.MeshStandardMaterial({color:'#c3b79e',metalness:.55,roughness:.4}));
 rod.rotation.z=Math.PI/2;rod.position.set(w.x+w.width/2,top+.035,.16);root.add(rod);
 function panel(side){const group=new THREE.Group();group.position.set(side==='left'?w.x-.08:w.x+w.width+.08,top,.14);root.add(group);
  const geometry=new THREE.PlaneGeometry(1,height,40,24),p=geometry.attributes.position;
  for(let i=0;i<p.count;i++){const x=p.getX(i)+.5,y=p.getY(i)-height/2; p.setXYZ(i,x,y,.024*Math.cos(x*Math.PI*16)+.008*Math.sin(y*5+x*11));}geometry.computeVertexNormals();
  const mesh=new THREE.Mesh(geometry,cloth);mesh.castShadow=true;mesh.receiveShadow=true;mesh.userData.curtainSide=side;group.add(mesh);interactive.push(mesh);
  const hem=new THREE.PlaneGeometry(1,.12,40,3),hp=hem.attributes.position;
  for(let i=0;i<hp.count;i++){const x=hp.getX(i)+.5;hp.setXYZ(i,x,hp.getY(i)-height+.01,.024*Math.cos(x*Math.PI*16)+.012);}hem.computeVertexNormals();
  const trim=new THREE.Mesh(hem,lace);group.add(trim);
  for(let i=0;i<9;i++){const ring=new THREE.Mesh(new THREE.TorusGeometry(.018,.003,6,12),rod.material);ring.position.set(i/8,.02,0);group.add(ring);}
  panels.push({group,side});
 }
 panel('left');panel('right');
 const slider=document.getElementById('curtain-range'),button=document.getElementById('curtain-toggle');
 function update(value){openness=THREE.MathUtils.clamp(value,0,1);for(const {group,side} of panels)group.scale.x=curtainWidth(openness,fullWidth)*(side==='left'?1:-1);
  sun.intensity=1.1+1.9*openness;if(slider)slider.value=String(Math.round(openness*100));if(button)button.textContent=openness>.5?'合上窗帘':'拉开窗帘';invalidate();
 }
 if(slider)slider.oninput=()=>update(Number(slider.value)/100);
 if(button)button.onclick=()=>update(openness>.5?0:1);
 const ray=new THREE.Raycaster(),pointer=new THREE.Vector2(),events=[];
 const on=(name,fn)=>{canvas.addEventListener(name,fn,true);events.push([name,fn]);};
 function release(){drag=null;controls.enabled=true;}
 on('pointerdown',e=>{
  if(drag){release();return;}
  if(!wallGroup.visible)return;
  const r=canvas.getBoundingClientRect();pointer.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);ray.setFromCamera(pointer,camera);
  const hit=ray.intersectObjects(interactive,false)[0];if(!hit)return;
  // Project the world x axis so left/right dragging also works when orbiting behind the scene.
  const a=new THREE.Vector3(w.x,top,.14).project(camera),b=new THREE.Vector3(w.x+1,top,.14).project(camera);
  const vx=(b.x-a.x)*r.width/2,vy=-(b.y-a.y)*r.height/2,length=Math.hypot(vx,vy);
  if(length<8)return;
  drag={id:e.pointerId,x:e.clientX,y:e.clientY,start:openness,side:hit.object.userData.curtainSide,vx:vx/length,vy:vy/length,pixels:Math.max(40,length*fullWidth*.76)};
  controls.enabled=false;canvas.setPointerCapture?.(e.pointerId);e.stopImmediatePropagation();e.preventDefault();
 });
 on('pointermove',e=>{if(!drag||e.pointerId!==drag.id)return;const dx=(e.clientX-drag.x)*drag.vx+(e.clientY-drag.y)*drag.vy;update(dragOpenness(drag.start,dx,drag.side,drag.pixels));selection.textContent='窗帘开合仅在房间内生效，不会发送聊天消息。';e.stopImmediatePropagation();e.preventDefault();});
 for(const event of ['pointerup','pointercancel','lostpointercapture'])on(event,e=>{if(drag&&e.pointerId===drag.id){release();if(canvas.hasPointerCapture?.(e.pointerId))canvas.releasePointerCapture(e.pointerId);e.stopImmediatePropagation();}});
 update(openness);
 return {reset:release,dispose(){release();events.forEach(([n,f])=>canvas.removeEventListener(n,f,true));}};
}
