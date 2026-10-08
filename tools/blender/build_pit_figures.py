# The army pits' other figures, taken out of the jam's terracotta workshop
# (TripoModels/TerracottaRoom.glb) into assets/models/props/figures/:
#   warrior_armored.glb  an armoured warrior, arms at his sides
#   figure_legs.glb      a figure broken off above the hips: legs on a plinth
#   figure_head.glb      a head with its topknot, fallen
# Like TripoModels/statue1-idle.glb (the infantryman with clasped hands, the
# ranks' main figure): about a unit tall, facing +x, its lowest point on z = 0,
# centred over the origin; the textures go with them.
#
#   blender -b --python tools/blender/build_pit_figures.py

import bpy, os
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "TerracottaRoom.glb")
OUT = os.path.join(ROOT, "assets", "models", "props", "figures")
PIECES = [
	("tripo_node_1f81c25f-937f-4295-b633-13e56fc8695b", "warrior_armored"),
	("tripo_node_50f1d62e-4661-4fcc-9639-fb0d08fe7406", "figure_legs"),
	("tripo_node_000b2929-e822-4b65-9ed3-d59ceee77067", "figure_head"),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
os.makedirs(OUT, exist_ok=True)
for src_name, out_name in PIECES:
	src = bpy.data.objects[src_name]
	# A fresh object on the same mesh, without the room's placing: the mesh
	# as the generator made it, facing +x.
	mesh = src.data.copy()
	pts = [v.co for v in mesh.vertices]
	lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
	hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
	mesh.transform(Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
	ob = bpy.data.objects.new(out_name, mesh)
	bpy.context.scene.collection.objects.link(ob)
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	path = os.path.join(OUT, out_name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True)
	print("built", path, "size", tuple(round(d, 3) for d in (hi - lo)))
