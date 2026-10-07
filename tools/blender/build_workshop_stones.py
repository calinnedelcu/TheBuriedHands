# The stones the workshop is built of, as separate pieces for the level kit
# (Scripts/world/masonry.gd): the dressed blocks of its west wall (Cube.014)
# and the flagstones of its floor (Cube.047), taken out of the main map
# (scenes/items/MapWithoutTreasure.glb), each centred on its own origin.
# Wall stones are turned so they lie along x, stand along z and show their
# worked face toward -y (Godot: along x, up y, face +z); floor stones keep
# their top up.
#
#   blender -b --python tools/blender/build_workshop_stones.py
#
# Writes assets/models/level/workshop_stones.glb (objects Wall_00.., Floor_00..).

import bpy, bmesh, os, math
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "scenes", "items", "MapWithoutTreasure.glb")
DST = os.path.join(ROOT, "assets", "models", "level", "workshop_stones.glb")
WALL_STONES = 12
FLOOR_STONES = 8


def split_loose(name):
	"""A copy of object `name`, its doubled vertices merged, cut into its
	loose parts, transforms applied."""
	src = bpy.data.objects[name]
	ob = src.copy()
	ob.data = src.data.copy()
	bpy.context.scene.collection.objects.link(ob)
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	bm = bmesh.new()
	bm.from_mesh(ob.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
	bm.to_mesh(ob.data)
	bm.free()
	bpy.ops.object.mode_set(mode='EDIT')
	bpy.ops.mesh.select_all(action='SELECT')
	bpy.ops.mesh.separate(type='LOOSE')
	bpy.ops.object.mode_set(mode='OBJECT')
	return [o for o in bpy.context.selected_objects]


def bounds(ob):
	pts = [v.co for v in ob.data.vertices]
	mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
	mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
	return mn, mx


def centre(ob):
	mn, mx = bounds(ob)
	c = (mn + mx) * 0.5
	ob.data.transform(Matrix.Translation(-c))
	ob.location = (0, 0, 0)


def worked_side(ob, axis):
	"""+1 or -1: the side of `axis` with the more faces (the worked face;
	the back, against the wall's core, is plainer)."""
	plus = minus = 0.0
	for p in ob.data.polygons:
		n = p.normal[axis]
		if n > 0.3:
			plus += 1
		elif n < -0.3:
			minus += 1
	return 1.0 if plus >= minus else -1.0


def pick(parts, count, key):
	"""`count` parts spread evenly over the range of `key`."""
	parts = sorted(parts, key=key)
	if len(parts) <= count:
		return parts
	step = (len(parts) - 1) / (count - 1)
	return [parts[round(i * step)] for i in range(count)]


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
keep = []

# Wall stones: thin across the wall (x here), along it in y, up in z.
walls = []
for ob in split_loose("Cube.014"):
	mn, mx = bounds(ob)
	d = mx - mn
	if len(ob.data.polygons) >= 120 and 0.3 < d.x < 0.65 and 0.4 < d.y < 1.0 and 0.4 < d.z < 0.95:
		walls.append(ob)
	else:
		bpy.data.objects.remove(ob)
print("wall stones found:", len(walls))
chosen = pick(walls, WALL_STONES, lambda o: (bounds(o)[1] - bounds(o)[0]).y / (bounds(o)[1] - bounds(o)[0]).z)
for o in walls:
	if o not in chosen:
		bpy.data.objects.remove(o)
for i, ob in enumerate(chosen):
	centre(ob)
	# Worked face (±x) to -y, length (y) to x: a quarter turn about z.
	side = worked_side(ob, 0)
	ob.data.transform(Matrix.Rotation(-math.pi * 0.5 * side, 4, 'Z'))
	ob.name = ob.data.name = "Wall_%02d" % i
	keep.append(ob)

# Floor stones: flat in x and y, their tops up (z).
floors = []
for ob in split_loose("Cube.047"):
	mn, mx = bounds(ob)
	d = mx - mn
	if len(ob.data.polygons) >= 60 and 0.35 < d.z < 0.6 and min(d.x, d.y) > 0.9:
		floors.append(ob)
	else:
		bpy.data.objects.remove(ob)
print("floor stones found:", len(floors))
chosen = pick(floors, FLOOR_STONES, lambda o: max((bounds(o)[1] - bounds(o)[0]).x, (bounds(o)[1] - bounds(o)[0]).y) / min((bounds(o)[1] - bounds(o)[0]).x, (bounds(o)[1] - bounds(o)[0]).y))
for o in floors:
	if o not in chosen:
		bpy.data.objects.remove(o)
for i, ob in enumerate(chosen):
	centre(ob)
	# The long side along x.
	mn, mx = bounds(ob)
	if (mx - mn).y > (mx - mn).x:
		ob.data.transform(Matrix.Rotation(math.pi * 0.5, 4, 'Z'))
	ob.name = ob.data.name = "Floor_%02d" % i
	keep.append(ob)

for ob in list(bpy.data.objects):
	if ob not in keep:
		bpy.data.objects.remove(ob)
for i, ob in enumerate(keep):
	mn, mx = bounds(ob)
	print("%s: %d faces, size %.2f x %.2f x %.2f" % (ob.name, len(ob.data.polygons), *(mx - mn)))
os.makedirs(os.path.dirname(DST), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', use_selection=True, export_apply=True, export_animations=False)
print("wrote", DST)
