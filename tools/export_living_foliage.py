"""Export small, shared game meshes from the approved Blender forest study.
Run in background Blender. Does not modify the preview or the open Blender scene.
"""
import bpy, json
from pathlib import Path
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'blender-previews/living-grove/living-grove-preview.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.frame_set(1)
deps = bpy.context.evaluated_depsgraph_get()
specs = [('broadleaf', 'Broadleaf plant'), ('fern', 'Fern / swaying crown'),
         ('canopy', 'Tree / leafy branch'), ('flower_coral', 'Flower / wind pivot'),
         ('flower_cream', 'Flower / wind pivot.001'), ('flower_lilac', 'Flower / wind pivot.002')]
out = ROOT / 'game-source/assets/living-grove'
out.mkdir(parents=True, exist_ok=True)
exported = []
report = []
palette = {}

def simple_material(source):
    if source.name in palette: return palette[source.name]
    m = bpy.data.materials.new('Game / ' + source.name)
    m.diffuse_color = source.diffuse_color
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = source.diffuse_color
    p.inputs['Roughness'].default_value = .78
    m.use_backface_culling = False
    palette[source.name] = m
    return m

for name, source_name in specs:
    pivot = bpy.data.objects[source_name]
    verts, faces, face_mats, mats = [], [], [], []
    # Bake all parts into one object; keep the silhouette and midrib, omit fine veins.
    for obj in pivot.children_recursive:
        if obj.type not in {'MESH', 'CURVE'} or ' / vein' in obj.name or 'tiny stamen' in obj.name: continue
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        transform = pivot.matrix_world.inverted() @ obj.matrix_world
        offset = len(verts)
        verts.extend(tuple(transform @ v.co) for v in mesh.vertices)
        for poly in mesh.polygons:
            source_mat = obj.data.materials[min(poly.material_index, len(obj.data.materials)-1)]
            mat = simple_material(source_mat)
            if mat not in mats: mats.append(mat)
            faces.append(tuple(offset + i for i in poly.vertices))
            face_mats.append(mats.index(mat))
        evaluated.to_mesh_clear()
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    for mat in mats: mesh.materials.append(mat)
    for poly, idx in zip(mesh.polygons, face_mats):
        poly.material_index = idx
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # A single mesh per plant, with compact material surfaces and no imported keys.
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')), use_selection=True,
        export_format='GLB', export_animations=False, export_cameras=False, export_lights=False)
    exported.append(obj)
    report.append({'asset':name, 'vertices':len(verts), 'faces':len(faces),
                   'bytes':(out/(name+'.glb')).stat().st_size})

# Keep an editable Blender kit in the repository, independent of the preview folder.
for obj in list(bpy.data.objects):
    if obj not in exported: bpy.data.objects.remove(obj, do_unlink=True)
scene.name = 'Living Grove — game foliage kit'
for i, obj in enumerate(exported): obj.location = ((i%3)*3, (i//3)*3, 0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/living_grove_foliage.blend'))
(out/'export-summary.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report), flush=True)
