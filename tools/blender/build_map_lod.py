# Lightens the main map (scenes/items/MapWithoutTreasure.glb) by decimating
# its absurdly dense decorative meshes, keeping every node's name, place and
# material, so the level's edits on them still apply (small details such as
# the oil-lamp holders' flames would be lost, so those stay as they are):
#   cloth banners (Plane.00x, 144 k triangles each)   -> 4 %
#   ceiling slabs ("Roof" material, 50-90 k each)     -> 30 %
#   the barred doors (LockedDoor, Plane.002)           -> 30 %
# The untouched source is not in the working tree: see
# TripoModels/source/README.md to restore it into TripoModels/source/.
#
#   blender -b --python tools/blender/build_map_lod.py

import bpy, os, re, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "source", "MapWithoutTreasure.glb")
DST = os.path.join(ROOT, "scenes", "items", "MapWithoutTreasure.glb")


def ratio_for(ob):
	name = ob.name
	mats = [m.name for m in ob.data.materials if m]
	faces = len(ob.data.polygons)
	if re.fullmatch(r"Plane\.0(0[1-7]|17)", name) and "Cloth" in mats:
		return 0.04
	if mats == ["Roof"] and faces > 30000:
		return 0.3
	if name in ("LockedDoor", "Plane.002"):
		return 0.3
	return None


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
print("actions", len(bpy.data.actions), "objects", len(bpy.data.objects))
before = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
t = time.time()
for ob in [o for o in bpy.data.objects if o.type == 'MESH']:
	r = ratio_for(ob)
	if r is None:
		continue
	if ob.data.users > 1:
		ob.data = ob.data.copy()
	bpy.ops.object.select_all(action='DESELECT')
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	mod = ob.modifiers.new("Decimate", 'DECIMATE')
	mod.decimate_type = 'COLLAPSE'
	mod.ratio = r
	mod.use_collapse_triangulate = True
	bpy.ops.object.modifier_apply(modifier=mod.name)
after = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print("faces %d -> %d in %.1f s" % (before, after, time.time() - t))
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=False,
		export_animations=len(bpy.data.actions) > 0)
print("built", DST)
