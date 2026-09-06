import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
export function addDetails({scene,L,box,label,textures,pickables}) {
 const mat=(color,opts={})=>new THREE.MeshStandardMaterial({color,roughness:.85,...opts});
 const white=mat('#ebe9e4'),iron=mat('#e6e6e2',{metalness:.35,roughness:.44}),darkMetal=mat('#5c5b5a',{metalness:.65,roughness:.35});
 const brass=mat('#a5987a',{metalness:.7,roughness:.35}),wood=mat('#b7a591'),fabric=mat('#e1d6d3');
 const B=(w,h,d,x,y,z,m,tag,parent=scene)=>box(parent,w,h,d,x,y,z,m,tag);
 function rounded(w,h,d,x,y,z,m,tag,r=.035,parent=scene){
  const mesh=new THREE.Mesh(new RoundedBoxGeometry(w,h,d,3,Math.min(r,w/3,h/3,d/3)),m);
  mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;parent.add(mesh);
  if(tag){mesh.userData.description=tag;pickables.push(mesh);}return mesh;
 }
 function texture(draw){const c=document.createElement('canvas');c.width=c.height=512;draw(c.getContext('2d'));const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;textures.push(t);return t;}
 const check=texture(ctx=>{ctx.fillStyle='#e8e2d9';ctx.fillRect(0,0,512,512);ctx.fillStyle='#ccc8bf';for(let y=0;y<8;y++)for(let x=0;x<8;x++)if((x+y)%2===0)ctx.fillRect(x*64,y*64,64,64);});
 check.wrapS=check.wrapT=THREE.RepeatWrapping;check.repeat.set(3,1);
 const dots=texture(ctx=>{ctx.fillStyle='#e2d5d3';ctx.fillRect(0,0,512,512);ctx.fillStyle='#a99c9e';for(let y=0;y<8;y++)for(let x=0;x<8;x++){ctx.beginPath();ctx.arc(x*64+32+(y%2)*12,y*64+32,4.5,0,Math.PI*2);ctx.fill();}});
 const cloth=mat('#ffffff',{map:check}), dotted=mat('#ffffff',{map:dots});
 const d=L.desk,desk='浅色棋盘格桌布，书桌背后是两扇窗。';
 rounded(d.width,.065,d.depth,1,d.height,.275,white,desk);
 for(const x of [.07,1.93])for(const z of [.06,.49])B(.04,d.height,.04,x,d.height/2,z,white,desk);
 B(d.width,.012,d.depth,1,d.height+.04,.275,cloth,desk);
 B(d.width,.12,.008,1,d.height-.015,.554,cloth,desk);
 label('书桌',1,1,.3);
 const b=L.bed,bed='1.5 × 2 米床；床头朝左，低饱和波点床品。';
 rounded(2,.24,1.5,1,.22,b.z+.75,white,bed);
 rounded(1.96,.22,1.46,1,.44,b.z+.75,mat('#eee9e2'),bed,.075);
 rounded(.07,.86,1.5,.025,.44,b.z+.75,white,bed);
 for(const z of [b.z+.4,b.z+1.1]){
   const p=rounded(.48,.15,.56,.31,.61,z,mat('#eae3dc'),bed,.072);p.rotation.z=-.07;
 }
 // Low-poly cloth surface: draped sides and restrained waves instead of a rigid cuboid.
 const g=new THREE.PlaneGeometry(1.49,1.5,40,32),a=g.attributes.position;
 for(let i=0;i<a.count;i++){
  const u=a.getX(i),v=a.getY(i);
  const edge=Math.max(0,(Math.abs(v)-.64)/.11);
  const y=.59+.012*Math.sin(u*17+v*9)+.008*Math.sin(v*24)-edge*edge*.19;
  a.setXYZ(i,u,y,v);
 }
 g.computeVertexNormals();const quilt=new THREE.Mesh(g,dotted);quilt.position.set(1.245,0,b.z+.75);quilt.material.side=THREE.DoubleSide;quilt.castShadow=true;quilt.receiveShadow=true;scene.add(quilt);
 quilt.userData.description=bed;pickables.push(quilt);
 rounded(.22,.1,1.46,.59,.61,b.z+.75,fabric,bed,.04);
 // Small tone-on-tone wing motif on an accent cushion, generated geometrically.
 const pillow=rounded(.34,.13,.34,.4,.72,b.z+.82,mat('#ded4c8'),bed,.055);pillow.rotation.y=.1;
 const angel=mat('#b8aa98');
 for(const sign of [-1,1]){const wing=new THREE.Mesh(new THREE.SphereGeometry(1,12,8),angel);wing.scale.set(.07,.012,.12);wing.position.set(.4+sign*.066,.79,b.z+.82);wing.rotation.y=sign*.4;scene.add(wing);}
 const head=new THREE.Mesh(new THREE.SphereGeometry(.035,12,8),angel);head.scale.y=.25;head.position.set(.4,.795,b.z+.71);scene.add(head);
 label('床头 ←',.36,.99,b.z+.65);
 const w=L.wardrobe,ward='哑光白木衣柜，上下分柜，弯形金属把手。';
 B(w.width,w.height,w.depth,w.width/2,w.height/2,w.z+w.depth/2,white,ward);
 for(let i=0;i<4;i++)for(const [bottom,height] of [[.04,1.89],[1.96,.52]]){
  const x=(i+.5)*w.width/4;
  rounded(w.width/4-.014,height,.028,x,bottom+height/2,w.z-.016,white,ward,.008);
  const hx=x+(i%2===0?.16:-.16),hy=bottom+(height>.6?1.02:.22);
  const curve=new THREE.CatmullRomCurve3([new THREE.Vector3(hx,hy-.065,w.z-.035),new THREE.Vector3(hx+.012,hy,w.z-.07),new THREE.Vector3(hx,hy+.065,w.z-.035)]);
  const handle=new THREE.Mesh(new THREE.TubeGeometry(curve,12,.008,6,false),brass);scene.add(handle);
 }
 label('衣柜',1,w.height+.08,w.z+.25);
 const c=L.cabinet,cab='白铁皮玻璃柜：封顶、分层玻璃门，侧面洞洞板；柜顶在窗户约半高处。';
 const cx=c.x+c.width/2,cz=c.z+c.depth/2;
 for(const x of [c.x,c.x+c.width])B(.024,c.height,c.depth,x,c.height/2,cz,iron,cab);
 B(c.width,c.height,.02,cx,c.height/2,c.z,iron,cab);
 for(let i=0;i<=3;i++)B(c.width,.025,c.depth,cx,.035+i*(c.height-.05)/3,cz,iron,cab);
 const glass=mat('#d7e4e1',{transparent:true,opacity:.23,metalness:.05,roughness:.16,depthWrite:false});
 for(let i=0;i<3;i++){
  const y=.04+(i+.5)*(c.height-.07)/3,hh=(c.height-.07)/3-.025;
  B(c.width-.045,hh,.008,cx,y,c.z+c.depth+.008,glass,cab);
  for(const x of [c.x+.02,c.x+c.width-.02])B(.026,hh,.023,x,y,c.z+c.depth+.02,iron,cab);
  for(const yy of [y-hh/2,y+hh/2])B(c.width,.025,.023,cx,yy,c.z+c.depth+.02,iron,cab);
  const knob=new THREE.Mesh(new THREE.SphereGeometry(.019,12,8),brass);knob.position.set(cx,y-hh/2+.045,c.z+c.depth+.045);scene.add(knob);
  // A few neutral books/boxes behind the glass, not copied private photo textures.
  for(let j=0;j<3;j++)B(.095,.12+.025*j,.16,c.x+.14+j*.16,y-hh/2+.1,c.z+.2,mat(['#c8b8bd','#b9c2bd','#d4cbbb'][j]),cab);
 }
 B(.018,.83,.42,c.x-.018,c.height-.46,cz,iron,cab);
 const holes=mat('#aaa9a3');for(let y=0;y<8;y++)for(let z=0;z<4;z++){
  const hole=new THREE.Mesh(new THREE.CircleGeometry(.006,6),holes);hole.rotation.y=-Math.PI/2;hole.position.set(c.x-.028,c.height-.81+y*.09,c.z+.1+z*.075);scene.add(hole);
 }
 label('玻璃柜',cx,c.height+.14,cz);
 const s=L.shelf,shelf='白色细铁架，顶部敞开，高度保持不变。';
 for(const x of [s.x,s.x+s.width])for(const z of [s.z,s.z+s.depth])B(.018,s.height,.018,x,s.height/2,z,iron,shelf);
 for(const y of [.06,.46,.88,1.3])B(s.width,.018,s.depth,s.x+s.width/2,y,s.z+s.depth/2,iron,shelf);
 // A picture frame and a bag give scale without reproducing personal images.
 B(.016,.32,.42,s.x+.23,1.48,s.z+.45,brass,shelf);B(.02,.28,.38,s.x+.217,1.48,s.z+.45,mat('#c6bbb0'),shelf);
 rounded(.23,.23,.34,s.x+.16,.59,s.z+.36,mat('#d7cdc3'),shelf);
 label('开放铁架',s.x+.15,s.height+.13,s.z+.48);
 // Acoustic guitar in the gap; all children belong to one transform and sit on a stand.
 const guitar=new THREE.Group();guitar.position.set(2.91,0,.86);guitar.rotation.y=-Math.PI/2;guitar.rotation.x=-.07;scene.add(guitar);
 const shape=new THREE.Shape();shape.moveTo(0,.1);shape.bezierCurveTo(-.26,.08,-.25,.35,-.14,.4);shape.bezierCurveTo(-.09,.45,-.2,.52,-.12,.59);shape.bezierCurveTo(-.06,.66,.06,.66,.12,.59);shape.bezierCurveTo(.2,.52,.09,.45,.14,.4);shape.bezierCurveTo(.25,.35,.26,.08,0,.1);
 const body=new THREE.Mesh(new THREE.ExtrudeGeometry(shape,{depth:.085,bevelEnabled:true,bevelThickness:.008,bevelSize:.008,bevelSegments:2,steps:1,curveSegments:12}),mat('#b48b64'));body.castShadow=true;guitar.add(body);
 B(.043,.39,.027,0,.8,.04,mat('#6f5948'),'木吉他与落地支架',guitar);rounded(.067,.13,.034,0,1.055,.04,wood,'木吉他',.01,guitar);
 const sound=new THREE.Mesh(new THREE.CircleGeometry(.064,24),mat('#4f4339'));sound.position.set(0,.43,.095);guitar.add(sound);
 B(.13,.023,.015,0,.26,.103,darkMetal,'琴桥',guitar);
 for(let i=0;i<6;i++)B(.0012,.77,.0012,(i-2.5)*.005,.635,.107,brass,null,guitar);
 for(const sign of [-1,1]){const leg=B(.018,.3,.018,sign*.1,.16,.03,darkMetal,null,guitar);leg.rotation.z=sign*.43;}
 B(.023,.55,.023,0,.29,-.055,darkMetal,null,guitar);
 label('吉他',2.85,1.2,.86);
}


export function woodFloorTexture(textures) {
 const c=document.createElement('canvas');c.width=c.height=512;const ctx=c.getContext('2d');
 ctx.fillStyle='#c7c1b8';ctx.fillRect(0,0,512,512);
 let seed=47;const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
 for(let i=0;i<340;i++){
  const x=rand()*512;ctx.beginPath();ctx.moveTo(x,0);
  const bend=(rand()-.5)*9;ctx.bezierCurveTo(x+bend,180,x-bend,330,x,512);
  ctx.strokeStyle=rand()>.5?'rgba(102,96,88,.10)':'rgba(255,254,248,.15)';ctx.lineWidth=.3+rand()*.8;ctx.stroke();
 }
 const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(3,2);textures.push(t);return t;
}
