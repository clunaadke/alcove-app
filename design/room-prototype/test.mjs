import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { layout as L } from './layout.mjs';
import * as THREE from 'three';
test('bed is 2m across, 1.5m down; head left; desk touches upper edge',()=>{
 assert.equal(L.bed.width,2);assert.equal(L.bed.depth,1.5);assert.equal(L.bed.head,'left');
 assert.equal(L.desk.z+L.desk.depth,L.bed.z);assert.equal(L.bed.x,0);
});
test('furniture stays in the room and footprints do not overlap',()=>{
 const items=['bed','desk','wardrobe','cabinet','shelf'].map(k=>[k,L[k]]);
 for(const [name,o] of items){assert.ok(o.x>=0&&o.z>=0,name);assert.ok(o.x+o.width<=L.room.width+.0001&&o.z+o.depth<=L.room.depth+.0001,name);}
 for(let i=0;i<items.length;i++)for(let j=i+1;j<items.length;j++){
 const [na,a]=items[i],[nb,b]=items[j];
 const overlap=Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x)>1e-6&&Math.min(a.z+a.depth,b.z+b.depth)-Math.max(a.z,b.z)>1e-6;
 assert.equal(overlap,false,`${na}/${nb}`);
 }
 assert.ok(L.wardrobe.z-(L.bed.z+L.bed.depth)>.5);
 assert.ok(L.door.x>L.wardrobe.x+L.wardrobe.width);
});
test('camera framing contains the room corners in portrait and landscape',()=>{
 for(const aspect of [.5,.65,1,1.8])for(const top of [true,false]){
  const c=new THREE.PerspectiveCamera(38,aspect,.05,60),target=new THREE.Vector3(1.65,.55,1.675);
  const angle=Math.atan(Math.tan(THREE.MathUtils.degToRad(19))*Math.min(aspect,1));
  const d=Math.min(23,2.9/Math.sin(angle));
  const dir=top?new THREE.Vector3(0,1,.0001):new THREE.Vector3(1,1.2,1.15).normalize();
  c.position.copy(target).addScaledVector(dir,d);c.lookAt(target);c.updateMatrixWorld();
  for(const x of [-.1,3.3])for(const y of [0,2.6])for(const z of [-.1,3.35]){
   const p=new THREE.Vector3(x,y,z).project(c);assert.ok(Math.abs(p.x)<=1&&Math.abs(p.y)<=1,`aspect ${aspect} top ${top}: ${p.x},${p.y}`);
  }
 }
});
test('HTML loads only bundled scripts; native route points at correct assets',()=>{
 const html=readFileSync(new URL('../../www/room3d/index.html',import.meta.url),'utf8');
 for(const m of html.matchAll(/<script src="([^"]+)"/g))assert.ok(existsSync(new URL('../../www/room3d/'+m[1],import.meta.url)));
 const swift=readFileSync(new URL('../../ios/App/App/NativeChat/NativeHouseViews.swift',import.meta.url),'utf8');
 assert.ok(swift.includes('case .room3d:'));assert.ok(swift.includes('assetDirectory: "room3d", lifecycleObject: "alcoveRoom3D"'));
});
