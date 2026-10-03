"""Original Blender assets for Melody Grove's enclosed forest valley.
Run with Blender --background --threads 4 --python tools/build_forest_valley.py.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'game-source/assets/forest-valley'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
rng = random.Random(71)

def mat(name, color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.83
    return m
bark=mat('Warm cedar bark',(.22,.105,.055))
leaves=[mat('Pine needles '+str(i),c) for i,c in enumerate([(.075,.22,.15),(.105,.285,.18),(.145,.33,.21),(.19,.37,.24)])]
stone=[mat('Weathered blue stone '+str(i),c) for i,c in enumerate([(.35,.43,.48),(.42,.49,.52),(.31,.38,.43),(.45,.5,.48)])]
moss=mat('Rock moss',(.23,.32,.17))
reeds=mat('Pond reeds',(.2,.34,.15)); seed=mat('Reed seed heads',(.29,.15,.07))

def mesh(name,v,f,mats,indices=None,smooth=False):
    data=bpy.data.meshes.new(name); data.from_pydata(v,[],f); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    for m in mats:data.materials.append(m)
    for p in data.polygons:
        p.material_index=indices[p.index] if indices else 0; p.use_smooth=smooth
    return o

def beam(name,a,b,r1,r2,material):
    delta=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=9,radius1=r1,radius2=r2,depth=delta.length,location=(Vector(a)+Vector(b))/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(material)
    return o

def combine(name,items):
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:o.select_set(True)
    bpy.context.view_layer.objects.active=items[0]
    bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return o

def export(name,items):
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

trunks=[beam('Pine trunk',(0,0,0),(.09,-.06,12),.34,.035,bark)]
v=[]; f=[]; mi=[]
# Each bough has a ridged, serrated fan silhouette, not stacked cone primitives.
for tier in range(10):
    z=3.0+tier*.86; length=(12.1-z)*.33
    for branch in range(7):
        angle=branch*math.tau/7+tier*.47+rng.uniform(-.16,.16)
        length_here=length*rng.uniform(.85,1.12)
        direction=Vector((math.cos(angle),math.sin(angle),0)); side=Vector((-direction.y,direction.x,0))
        start=Vector((0,0,z+.3)); end=direction*length_here+Vector((0,0,z-.48))
        trunks.append(beam('Drooping bough',start,end,.07*(1-tier*.065),.015,bark))
        for spray in range(3):
            center=direction*(length_here*(.22+spray*.22))+Vector((0,0,z+.42-spray*.21))
            reach=length_here*(.7-spray*.10); width=length_here*(.31-spray*.04)
            base=len(v)
            # ridge plus toothed left/right skirt, continuous closed bough surface.
            coords=[(0,0,.26),(.38*reach,0,.2),(reach,0,-.33)]
            for sign in [1,-1]:
                coords += [(0,sign*width*.48,-.09),(.17*reach,sign*width,-.12),(.3*reach,sign*width*.68,-.1),(.46*reach,sign*width*.82,-.22),(.62*reach,sign*width*.41,-.20),(.77*reach,sign*width*.43,-.28)]
            for x,y,h in coords:v.append(tuple(center+direction*x+side*y+Vector((0,0,h))))
            faces=[(0,3,4,1),(1,4,5),(1,5,6),(1,6,7),(1,7,8,2),(0,1,10,9),(1,11,10),(1,12,11),(1,13,12),(1,2,14,13),(3,9,10,4),(4,10,11,5),(5,11,12,6),(6,12,13,7),(7,13,14,8),(8,14,2),(0,9,3)]
            for face in faces:f.append(tuple(base+j for j in face));mi.append((tier+branch+spray)%4)
trunk=combine('CedarTrunk',trunks)
crown=mesh('CedarCanopy',v,f,leaves,mi,True)
export('cedar',[trunk,crown])
# A broken asymmetric rock tower; repeated instances create the distant ridge.
v=[];f=[];mi=[]
for ring,(z,rad) in enumerate([(0,1),(.25,1.04),(1.0,.88),(1.9,.81),(2.6,.56),(3.2,.23)]):
    for j in range(9):
        angle=math.tau*j/9
        r=rad*rng.uniform(.82,1.14)
        v.append((math.cos(angle)*r+.12*z,math.sin(angle)*r,z+rng.uniform(-.12,.12)))
for k in range(5):
    for j in range(9):
        a=k*9+j;b=k*9+(j+1)%9;c=(k+1)*9+(j+1)%9;d=(k+1)*9+j
        f.extend([(a,b,c),(a,c,d)]);mi.extend([rng.randrange(4),rng.randrange(4)])
f.append(tuple(range(45,54)));mi.append(1)
crag=mesh('ValleyCrag',v,f,stone,mi)
export('crag',[crag])
# Small cattail group for irregular pond banks.
items=[]
for i in range(7):
    x=rng.uniform(-.45,.45);y=rng.uniform(-.3,.3);h=rng.uniform(.9,1.7)
    items.append(beam('Reed stem',(x,y,0),(x+.05,y,h),.018,.01,reeds))
    items.append(beam('Cattail',(x+.05,y,h-.2),(x+.05,y,h+.12),.055,.045,seed))
    for side in [-1,1]:
        items.append(mesh('Reed leaf',[(x,y,0),(x+side*.11,y+.025,h*.55),(x+side*.4,y,h*.8),(x+side*.04,y-.025,h*.43)],[(0,1,2,3),(3,2,1,0)],[reeds]))
reed=combine('Cattails',items);export('reeds',[reed])
# Organise the editable kit without changing exported coordinates.
crag.location.x=6;reed.location.x=9
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/forest_valley.blend'))
print('Saved forest valley Blender kit and 3 GLBs')
