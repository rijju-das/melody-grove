"""Extract full scenery from the approved Blender preview for the Godot forest."""
import bpy, math, json
from pathlib import Path
from mathutils import Matrix, Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R.parent/'blender-previews/living-grove/living-grove-preview.blend'))
bpy.context.scene.frame_set(1)
deps=bpy.context.evaluated_depsgraph_get(); exported=[]; palette={}
O=R/'game-source/assets/living-grove'
def mat(src):
 if src.name in palette:return palette[src.name]
 m=bpy.data.materials.new('Game scenery / '+src.name);m.diffuse_color=src.diffuse_color
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=src.diffuse_color;p.inputs['Roughness'].default_value=.82
 m.use_backface_culling=False;palette[src.name]=m;return m

def export(name,objects,origin,ratio=1):
 vs=[];fs=[];indices=[];mats=[]
 for obj in objects:
  if obj.type not in {'MESH','CURVE'} or ' / vein' in obj.name:continue
  ev=obj.evaluated_get(deps);mesh=ev.to_mesh();transform=Matrix.Translation(-Vector(origin))@obj.matrix_world;off=len(vs)
  vs.extend(tuple(transform@v.co) for v in mesh.vertices)
  for f in mesh.polygons:
   m=mat(obj.data.materials[min(f.material_index,len(obj.data.materials)-1)])
   if m not in mats:mats.append(m)
   fs.append(tuple(off+i for i in f.vertices));indices.append(mats.index(m))
  ev.to_mesh_clear()
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs)
 for m in mats:mesh.materials.append(m)
 for f,i in zip(mesh.polygons,indices):f.material_index=i;f.use_smooth=True
 obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 if ratio<1:
  mod=obj.modifiers.new('Game mesh simplification','DECIMATE');mod.ratio=ratio
  bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.ops.export_scene.gltf(filepath=str(O/(name+'.glb')),use_selection=True,export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
 exported.append(obj);print(name,len(obj.data.vertices),flush=True)
 return obj

def numbered(prefix,count):
 return [bpy.data.objects[prefix if i==0 else prefix+'.%03d'%i] for i in range(count)]
trunk=bpy.data.objects['Tree / sculpted trunk']; origin=trunk.data.splines[0].bezier_points[0].co.copy()
export('tree_trunk',[trunk]+numbered('Tree / spreading root',5)+numbered('Tree / curling bough',5)+numbered('Tree / vertical bark fluting',7),origin)
leaves=[]
for pivot in numbered('Tree / leafy branch',15):leaves+=list(pivot.children_recursive)
export('tree_canopy',leaves,origin,.4)
rock=bpy.data.objects['Pond edge / river stone']
export('moss_rock',[rock,bpy.data.objects['Stone / moss cap']],rock.location,.7)
lily=bpy.data.objects['Water lily / notched floating leaf']
center=sum((v.co for v in lily.data.vertices),Vector())/len(lily.data.vertices)
export('lily_pad',[lily],center)
grass=bpy.data.objects['Ground cover / curved grass blades']
# Five curved blades from the real Blender grass, merged into one reusable tuft.
verts=[v.co.copy() for v in grass.data.vertices[:25]]
faces=[tuple(p.vertices) for p in grass.data.polygons if max(p.vertices)<25]
me=bpy.data.meshes.new('Grass tuft');me.from_pydata(verts,[],faces);me.materials.append(grass.data.materials[0])
tu=bpy.data.objects.new('Grass tuft',me);bpy.context.scene.collection.objects.link(tu)
center=verts[0].copy();export('grass_tuft',[tu],center)
for obj in list(bpy.data.objects):
 if obj not in exported:bpy.data.objects.remove(obj,do_unlink=True)
for i,obj in enumerate(exported):obj.location=(i*7,0,0)
bpy.context.scene.name='Living Grove — full scenery kit'
bpy.ops.wm.save_as_mainfile(filepath=str(R/'art-source/living_grove_scenery.blend'))
