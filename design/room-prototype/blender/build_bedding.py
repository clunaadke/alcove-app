"""Blender-owned bed soft assets. Z-up construction -> standard glTF Y-up export.
Analytically sculpted folds (not a cloth simulation); exportable image materials.
"""
import bpy, math, os, sys, numpy as np
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.abspath(os.path.join(ROOT,'../../www/room3d/models'))
os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def image(name,base,dots=False):
 n=512;y,x=np.mgrid[:n,:n];arr=np.ones((n,n,4),dtype=np.float32)
 weave=.008*np.sin(x*math.pi)+.006*np.cos(y*2.1)
 for c,v in enumerate(base):arr[:,:,c]=v+weave
 if dots:
  mask=((x%64-32)**2+(y%64-32)**2)<4.0**2
  arr[mask,:3]=[.52,.46,.48]
 arr[:,:,3]=1
 im=bpy.data.images.new(name,width=n,height=n);im.pixels.foreach_set(arr.ravel());im.filepath_raw=os.path.join(OUT,name+'.png');im.file_format='PNG';im.save();im.pack();return im
cream=image('cream-weave',[.86,.83,.77]);pink=image('dusty-rose-dots',[.89,.88,.85],False)
def mat(name,color,im=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.95
 if im:
  node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
 return m
mcream=mat('Cream cotton',(.86,.83,.77),cream);mquilt=mat('Muted rose dot quilt',(.75,.67,.68),pink);mpipe=mat('Stitched cream piping',(.73,.69,.62));maccent=mat('Muted beige cushion',(.72,.66,.57),cream)
def mesh(name,verts,faces,material,uvs=None):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 if uvs:
  uv=me.uv_layers.new(name='UVMap')
  for p in me.polygons:
   for li in p.loop_indices:uv.data[li].uv=uvs[me.loops[li].vertex_index]
 for p in me.polygons:p.use_smooth=True
 return o
def world(x,h,d):return(x,-d,h)
def seam(name,points,r=.0028):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_depth=r;curve.bevel_resolution=2
 poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
 for p,co in zip(poly.points,points):p.co=(*co,1)
 obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);obj.data.materials.append(mpipe);return obj
# Quilt: softly uneven top, side overhangs, fold at head and slightly dropped foot.
nu,nv=72,72;verts=[];uv=[];faces=[]
for j in range(nv+1):
 v=j/nv;depth=.55-.045+v*1.59
 for i in range(nu+1):
  u=i/nu;x=.53+u*1.49;edge=max(0,(abs(depth-1.30)-.68)/.115)
  fold=.020*math.sin(x*13+depth*3)+.011*math.cos(depth*20-x*5)
  fold+=.042*math.exp(-((x-.67)/.11)**2)*math.sin(depth*10+.6)
  foot=max(0,(x-1.93)/.09)
  h=.64+fold-edge**1.35*.22-foot**1.5*.075
  verts.append(world(x,h,depth));uv.append((u*1.55,v*1.6))
for j in range(nv):
 for i in range(nu):a=j*(nu+1)+i;faces.append((a,a+nu+1,a+nu+2,a+1))
quilt=mesh('Quilt sculpted drape',verts,faces,mquilt,uv)
sol=quilt.modifiers.new('Cotton thickness','SOLIDIFY');sol.thickness=.012
seam('Quilt hem left',[verts[j*(nu+1)] for j in range(nv+1)])
seam('Quilt hem outer',[verts[j*(nu+1)+nu] for j in range(nv+1)])
seam('Quilt hem front',[verts[nv*(nu+1)+i] for i in range(nu+1)])
def pillow(name,cx,cz,width,depth,h,material):
 n=32;v=[];uv=[];f=[]
 for side in [1,-1]:
  for j in range(n+1):
   y=j/n*2-1
   for i in range(n+1):
    x=i/n*2-1;dome=max(0,1-x*x)**.6*max(0,1-y*y)**.6
    wrinkle=.005*math.cos(y*33+x*4)*math.exp(-(1-abs(x))*10)
    z=h+side*(.012+.065*dome)+wrinkle
    v.append(world(cx+x*width/2, z, cz+y*depth/2));uv.append((i/n,j/n))
 k=(n+1)**2
 for j in range(n):
  for i in range(n):
   a=j*(n+1)+i;f.append((a,a+n+1,a+n+2,a+1));f.append((k+a,k+a+1,k+a+n+2,k+a+n+1))
 rim=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
 for a,b in zip(rim,rim[1:]+rim[:1]):f.append((a,b,b+k,a+k))
 o=mesh(name,v,f,material,uv);seam(name+' seam',[world(v[i][0],h,-v[i][1]) for i in rim+[rim[0]]],.0025);return o
pillow('Single linen pillow',.28,1.30,.46,.65,.608,mcream)
# One normalized curtain panel; runtime mirrors/scales two copies and retains touch controls.
v=[];uv=[];f=[];nx=80;ny=40
for j in range(ny+1):
 t=j/ny
 for i in range(nx+1):
  x=i/nx;fold=.026*math.cos(x*math.pi*16)+.009*t*math.sin(x*13+t*3)
  h=-1.57*t-.012*t*t*(1+math.cos(x*math.pi*16))
  v.append(world(x,h,fold));uv.append((x,t))
for j in range(ny):
 for i in range(nx):
  a=j*(nx+1)+i;f.append((a,a+nx+1,a+nx+2,a+1))
curtain=mesh('CurtainPanelAsset',v,f,mcream,uv)
# Export before creating render-only room props/lights.
bpy.ops.object.select_all(action='SELECT')
for o in list(bpy.context.selected_objects):
 if o.type=='CURVE':bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender/bedding.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'bedding.glb'),export_format='GLB',use_selection=True,export_apply=True,export_materials='EXPORT',export_yup=True)
import base64
with open(os.path.join(OUT,'bedding.glb'),'rb') as fh:encoded=base64.b64encode(fh.read()).decode()
with open(os.path.join(ROOT,'bedding-data.mjs'),'w') as fh:fh.write('// Generated Blender GLB; bundled to avoid file XHR.\nexport default '+repr(encoded)+';\n')
print('ALCOVE_BEDDING_EXPORTED',os.path.join(OUT,'bedding.glb'))
