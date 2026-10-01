"""Build the editable Blender source and small GLB for Melody Grove's explorer."""
import bpy, math
from pathlib import Path
R=Path(__file__).resolve().parents[1]
(R/'art-source').mkdir(exist_ok=True)
(R/'game-source/assets').mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,hex):
 m=bpy.data.materials.new(name);m.use_nodes=True
 rgb=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
 color=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
 m.diffuse_color=color;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.72
 return m
skin=mat('Peach porcelain','F5CB9E');hair=mat('Chestnut curls','664533');ink=mat('Deep forest eyes','173D38');white=mat('Eye glints','FFF7DE');coat=mat('Teal explorer coat','3B9D8D');trim=mat('Jacket edge','226557');gold=mat('Honey scarf','F8C35B');boots=mat('Cinnamon boots','975C42');blush=mat('Rose cheeks','EA9984');hat=mat('Sage acorn cap','98AD69');leaf=mat('Fresh leaf','C3D590');bag=mat('Leather satchel','C79157')
def pivot(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
def ball(name,loc,scale,material,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1)
 o=bpy.context.object;o.name=name;o.parent=parent;o.location=loc;o.scale=scale;o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
root=pivot('ExplorerRoot',(0,0,0))
# Each limb has a proper shoulder/hip pivot for the existing game movement.
for x,side in [(-.22,'L'),(.22,'R')]:
 p=pivot('ExplorerLeg'+side,(x,0,.68),root)
 ball('Trouser'+side,(0,0,-.19),(.18,.18,.28),trim,p)
 ball('Boot'+side,(0,-.075,-.50),(.205,.30,.18),boots,p)
 ball('BootCuff'+side,(0,0,-.34),(.215,.205,.10),gold,p)
ball('ExplorerCoat',(0,0,1.00),(.43,.30,.49),coat,root)
ball('CoatHem',(0,0,.69),(.44,.31,.14),trim,root)
for z in [.87,1.08]:ball('BrassButton',(0,-.294,z),(.045,.025,.045),gold,root)
for x,side in [(-.43,'L'),(.43,'R')]:
 p=pivot('ExplorerArm'+side,(x,0,1.23),root)
 ball('Sleeve'+side,(x*.14,0,-.18),(.16,.18,.28),coat,p)
 ball('SleeveCuff'+side,(x*.18,-.005,-.35),(.16,.18,.075),trim,p)
 ball('Mitten'+side,(x*.19,-.025,-.44),(.155,.15,.18),skin,p)
ball('Satchel',(0,.31,.97),(.32,.18,.36),bag,root)
ball('SatchelFlap',(0,.45,1.13),(.33,.055,.20),boots,root)
ball('SatchelClasp',(0,.508,1.06),(.07,.025,.08),gold,root)
for x in [-.28,.28]:ball('ShoulderStrap',(x,-.245,1.05),(.052,.055,.32),bag,root)
ball('ScarfCollar',(0,-.015,1.38),(.38,.30,.13),gold,root)
scarf=pivot('ExplorerScarf',(.20,.13,1.36),root)
ball('ScarfTail',(.13,.17,-.24),(.13,.065,.31),gold,scarf)
head=pivot('ExplorerHead',(0,0,1.80),root)
ball('RoundFace',(0,-.03,0),(.49,.405,.47),skin,head)
for x in [-.48,.48]:ball('Ear',(x,-.02,-.025),(.115,.09,.15),skin,head)
ball('HairBack',(0,.135,.095),(.505,.34,.41),hair,head)
for x,z in [(-.31,.28),(-.13,.36),(.10,.37),(.30,.30)]:
 ball('ForeheadCurl',(x,-.32,z),(.16,.13,.14),hair,head)
for x,side in [(-.18,'L'),(.18,'R')]:
 eye=pivot('ExplorerEye'+side,(x,-.392,.01),head)
 ball('Eye'+side,(0,0,0),(.073,.045,.105),ink,eye)
 ball('EyeShine'+side,(-.023,-.037,.039),(.023,.014,.028),white,eye)
 ball('Cheek'+side,(x*1.60,-.353,-.14),(.095,.025,.05),blush,head)
ball('ButtonNose',(0,-.446,-.10),(.065,.07,.059),skin,head)
# Small curved smile, flattened so it reads at game-camera distance.
curve=bpy.data.curves.new('SmileCurve','CURVE');curve.dimensions='3D';curve.bevel_depth=.013;curve.bevel_resolution=2
sp=curve.splines.new('BEZIER');sp.bezier_points.add(2)
for bp,co in zip(sp.bezier_points,[(-.09,-.409,-.205),(0,-.43,-.236),(.09,-.409,-.205)]):bp.co=co;bp.handle_left_type=bp.handle_right_type='AUTO'
o=bpy.data.objects.new('GentleSmile',curve);bpy.context.collection.objects.link(o);o.parent=head;curve.materials.append(ink)
ball('CapCrown',(0,.03,.395),(.54,.45,.255),hat,head)
ball('CapBrim',(0,-.11,.34),(.57,.50,.065),trim,head)
ball('CapStem',(.05,.04,.64),(.055,.055,.12),boots,head)
petal=ball('CapLeaf',(.20,.04,.67),(.23,.09,.045),leaf,head);petal.rotation_euler.y=-.45
bpy.context.scene.name='Storybook Explorer'
bpy.ops.wm.save_as_mainfile(filepath=str(R/'art-source/storybook_explorer.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'game-source/assets/storybook_explorer.glb'),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
print('STORYBOOK EXPLORER EXPORTED')
