"""CPU raster of exported Three.js triangles. Simplified directional lighting, no shadow map."""
import numpy as np,json
from PIL import Image
for name in ['perspective','top']:
 rgb=np.empty((1000,1100,3),dtype=np.uint8);rgb[:]=[238,233,226];depth=np.full((1000,1100),np.inf);textures={}
 tris=json.load(open('/tmp/alcove-room-'+name+'.json'))
 # Opaque objects first, then translucent glass back-to-front against the opaque depth buffer.
 tris.sort(key=lambda t:(t['opacity']<1,-sum(p[2] for p in t['p'])/3 if t['opacity']<1 else 0))
 for t in tris:
  a,b,c=np.array(t['p']);lo=np.maximum(np.floor(np.minimum(np.minimum(a[:2],b[:2]),c[:2])).astype(int),[0,0]);hi=np.minimum(np.ceil(np.maximum(np.maximum(a[:2],b[:2]),c[:2])).astype(int),[1099,999])
  if np.any(hi<lo):continue
  den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-10:continue
  y,x=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];x=x+.5;y=y+.5
  u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den
  v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den;w=1-u-v;z=u*a[2]+v*b[2]+w*c[2]
  sub=depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1];mask=(u>=-1e-8)&(v>=-1e-8)&(w>=-1e-8)&(z<sub)
  color=np.broadcast_to(np.array(t['c']),(*mask.shape,3));alpha=np.full(mask.shape,t['opacity'])
  if t['map']:
   m=t['map'];key=m['id']
   if key not in textures:textures[key]=np.array(Image.open(f'/tmp/room-{name}-texture-{key}.png').convert('RGBA'))
   tex=textures[key];uv=np.array(t['uv']);q=u*a[3]+v*b[3]+w*c[3]
   uu=(u*a[3]*uv[0,0]+v*b[3]*uv[1,0]+w*c[3]*uv[2,0])/q
   vv=(u*a[3]*uv[0,1]+v*b[3]*uv[1,1]+w*c[3]*uv[2,1])/q
   tx=np.floor((uu*m['repeat'][0]%1)*(tex.shape[1]-1)).astype(int)
   vy=vv*m['repeat'][1]%1
   if m['flipY']:vy=1-vy
   ty=np.floor(vy*(tex.shape[0]-1)).astype(int);sample=tex[ty,tx]
   color=color*sample[:,:,:3]/255;alpha=alpha*sample[:,:,3]/255
   mask &= alpha>=max(.01,t['alphaTest'])
  dest=rgb[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
  dest[mask]=(color[mask]*alpha[mask,None]+dest[mask]*(1-alpha[mask,None])).clip(0,255).astype(np.uint8)
  if t['opacity']>=1:sub[mask]=z[mask]
 Image.fromarray(rgb).save('/tmp/alcove-room-'+name+'-final.png')
 print(name,'PNG saved')
