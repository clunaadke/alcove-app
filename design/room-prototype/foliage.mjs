import * as THREE from 'three';
// Small static foliage outside the window; shadows move with the existing sun.
export function addWindowFoliage(scene){
 const group=new THREE.Group();group.name='windowFoliage';scene.add(group);
 const leaf=new THREE.MeshStandardMaterial({color:'#60734a',roughness:1,side:THREE.DoubleSide});
 const bark=new THREE.MeshStandardMaterial({color:'#655341',roughness:1});
 let seed=312;const rnd=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
 let cluster;
 function branch(a,b,r){const start=new THREE.Vector3(...a),end=new THREE.Vector3(...b),delta=end.clone().sub(start);const m=new THREE.Mesh(new THREE.CylinderGeometry(r*.55,r,delta.length(),7),bark);m.position.copy(start).add(end).multiplyScalar(.5);m.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),delta.normalize());m.castShadow=true;cluster.add(m);}
 for(const shift of [-.75,0,.65]) {
 cluster=new THREE.Group();cluster.position.set(shift,shift===0?0:.12,-Math.abs(shift)*.18);group.add(cluster);
 branch([1.85,1.1,-.5],[1.32,2.65,-.55],.016);
 for(let k=0;k<5;k++){
  const y=1.35+k*.25,x=1.77-k*.085,end=x-(.35+rnd()*.4);
  branch([x,y,-.52],[end,y+.24,-.55],.008);
  for(let j=0;j<13;j++){
   const t=rnd(),mesh=new THREE.Mesh(new THREE.CircleGeometry(1,8),leaf);
   mesh.position.set(x+(end-x)*t+(rnd()-.5)*.18,y+.24*t+(rnd()-.5)*.26,-.52+(rnd()-.5)*.18);
   mesh.scale.set(.038+rnd()*.028,.065+rnd()*.028,1);mesh.rotation.set((rnd()-.5)*.7,(rnd()-.5)*.8,rnd()*Math.PI);mesh.castShadow=true;cluster.add(mesh);
  }
 }
 }
 for(const m of [leaf,bark]){m.colorWrite=false;m.depthWrite=false;}
 group.traverse(o=>{if(o.isMesh)o.userData.shadowOnly=true;});
 return group;
}
