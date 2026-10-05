# Builds assets/models/level/archive_scrolls.glb: the archives' shelves of
# scrolls (TripoModels/Testamente.glb, 1.9 M triangles, 148 MB) decimated to a
# fraction, with the same materials and placement, so the level loads and
# draws faster. The source is not in the working tree: see
# TripoModels/source/README.md to restore it.
#
#   blender -b --python tools/blender/build_archive_lod.py [-- ratio]

import bpy, bmesh, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "source", "Testamente.glb")
DST = os.path.join(ROOT, "assets", "models", "level", "archive_scrolls.glb")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RATIO = float(args[0]) if args else 0.22

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
print("source faces", len(ob.data.polygons))
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
t = time.time()
mod = ob.modifiers.new("Decimate", 'DECIMATE')
mod.decimate_type = 'COLLAPSE'
mod.ratio = RATIO
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("decimated faces", len(ob.data.polygons), "in", round(time.time() - t, 1), "s")
os.makedirs(os.path.dirname(DST), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print("built", DST)
