"""CPU Cycles preview of exported runtime geometry. Not an App screenshot."""
import bpy,json,math
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
meshes=json.load(open('/tmp/alcove-room-perspective-world.json'))
for i,m in enumerate(meshes):
 data=bpy.data.meshes.new(str(i));v=[(x,-z,y) for x,y,z in m['vertices']];ids=m['indices'];data.from_pydata(v,[],[ids[j:j+3] for j in range(0,len(ids),3)]);data.update();o=bpy.data.objects.new(str(i),data);bpy.context.collection.objects.link(o)
 mat=bpy.data.materials.new(str(i));mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*m['color'],1);bs.inputs['Roughness'].default_value=m['roughness'];bs.inputs['Metallic'].default_value=m['metalness']
 if m['opacity']<1:bs.inputs['Alpha'].default_value=m['opacity']
 if m.get('shadowOnly'):o.visible_camera=False;o.visible_glossy=False
 if not m['castShadow']:o.visible_shadow=False
 if m['map'] and m['uv']:
  layer=data.uv_layers.new();repeat=m['map']['repeat'];uv=m['uv']
  for loop in data.loops:
   u,w=uv[loop.vertex_index*2:loop.vertex_index*2+2];layer.data[loop.index].uv=(u*repeat[0],(w if m['map']['flipY'] else 1-w)*repeat[1])
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load('/tmp/room-perspective-texture-%d.png'%m['map']['id'],check_existing=True);mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
 data.materials.append(mat)
 for f in data.polygons:f.use_smooth=False
world=bpy.context.scene.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.78,.82,.9,1);world.node_tree.nodes['Background'].inputs[1].default_value=.30
bpy.ops.object.light_add(type='SUN',location=(.45,5.5,6.64));sun=bpy.context.object;sun.data.energy=3.0;sun.data.angle=.025;sun.data.color=(1,.95,.86);sun.rotation_euler=(Vector((.9,-1.2,.45))-sun.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(2,-4,5));bpy.context.object.data.energy=100;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
bpy.ops.object.camera_add(location=(7,-8,7));camera=bpy.context.object;target=Vector((1.98,-2.01,.7));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=6.6
s=bpy.context.scene;s.camera=camera;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.render.filepath='/tmp/room-french-preview.png';s.view_settings.view_transform='AgX'

# Composite the transparent room onto black, retaining the world as illumination.
s.use_nodes=True;nodes=s.node_tree.nodes;nodes.clear();rl=nodes.new('CompositorNodeRLayers');bg=nodes.new('CompositorNodeAlphaOver');bg.inputs[1].default_value=(0,0,0,1);out=nodes.new('CompositorNodeComposite');s.node_tree.links.new(rl.outputs['Image'],bg.inputs[2]);s.node_tree.links.new(bg.outputs['Image'],out.inputs['Image']);bpy.ops.render.render(write_still=True)
