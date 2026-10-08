# A suit of stone armour like those of pit K9801 by the First Emperor's
# mound: hundreds of small limestone plaques laced together with bronze wire,
# made for the dead. Built into assets/models/props/stone_armor.glb:
#   StoneArmor  the cuirass (chest and back down over the hips, its rows
#               overlapping like fish scales) and the two shoulder guards
# Game metres (the world is ~1.6x human scale); the armour stands on z = 0
# (its lower hem), faces +x like the clay figures, and hangs open at the neck.
#
#   blender -b --python tools/blender/build_stone_armor.py
#
# Materials are named: "Limestone" for the plaques, "Bronze" for the wire.

import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "models", "props", "stone_armor.glb")

PLAQUE = (0.072, 0.088, 0.012)   # across, up, thick
ROW = 0.068                       # the step between rows: each overlaps the one below
ROWS = 14
# From this row up the cuirass closes over the shoulders: arm holes at the
# sides, then only straps either side of the neck.
SHOULDER = 10

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(9801)


def material(name, color, metallic, roughness):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return m


MATS = [material("Limestone", (0.7, 0.66, 0.58), 0.0, 0.85), material("Bronze", (0.5, 0.36, 0.18), 1.0, 0.4)]


def half_axes(r):
	"""The cuirass's cross-section at row r: an ellipse (across, front to
	back), drawn in at the waist, flaring a little at the hem, and closing
	in over the shoulders toward the neck."""
	t = r / (ROWS - 1)
	across = 0.31 + 0.05 * math.sin(math.pi * min(1.0, t * 1.4)) - 0.035 * math.exp(-((t - 0.3) / 0.13) ** 2)
	deep = 0.205 + 0.03 * math.sin(math.pi * min(1.0, t * 1.4))
	if r >= SHOULDER:
		k = (r - SHOULDER + 1) / (ROWS - SHOULDER + 1)
		across *= 1.0 - 0.38 * k
		deep *= 1.0 - 0.3 * k
	return across, deep


def plaque(bm, centre, out, up, size, mat, tilt):
	"""A plaque: a thin bevel-less slab facing `out`, tipped out at the
	bottom by `tilt` so each row laps over the one below."""
	right = up.cross(out).normalized()
	up2 = (Matrix.Rotation(tilt, 4, right) @ up).normalized()
	out2 = right.cross(up2).normalized()
	w, h, t = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
	vs = []
	for a in (-w, w):
		for b in (-h, h):
			for c in (-t, t):
				vs.append(bm.verts.new(centre + right * a + up2 * b + out2 * c))
	faces = []
	for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
		f = bm.faces.new([vs[i] for i in q])
		f.material_index = mat
		faces.append(f)
	return faces


bm = bmesh.new()
# The cuirass, row by row from the hem up.
def keep(r, ang):
	side = abs(math.sin(ang))
	if r >= SHOULDER and side > 0.78:
		return False      # the arm holes
	if r >= SHOULDER + 2 and side < 0.36:
		return False      # the neck, front and back
	return True


for r in range(ROWS):
	z = r * ROW + PLAQUE[1] * 0.5
	a, b = half_axes(r)
	perimeter = 2 * math.pi * math.sqrt((a * a + b * b) * 0.5)
	n = max(8, int(perimeter / (PLAQUE[0] * 0.92)))
	# Over the shoulders the plaques lean in, following the slope.
	lean = math.radians(-9.0 - (24.0 if r >= SHOULDER + 1 else 0.0))
	for k in range(n):
		ang = 2 * math.pi * (k + (0.5 if r % 2 else 0.0)) / n
		if not keep(r, ang):
			continue
		p = Vector((a * math.cos(ang), b * math.sin(ang), z))
		# The outward normal of the ellipse there (the front faces +x).
		nrm = Vector((math.cos(ang) / a, math.sin(ang) / b, 0.0)).normalized()
		jitter = Vector((rnd.uniform(-0.002, 0.002), rnd.uniform(-0.002, 0.002), rnd.uniform(-0.002, 0.002)))
		plaque(bm, p + jitter, nrm, Vector((0, 0, 1)), PLAQUE, 0, lean)
	# The bronze wire lacing every other row, where there are plaques.
	if r % 2 == 0 and r < ROWS - 1:
		for k in range(n):
			ang0 = 2 * math.pi * k / n
			ang1 = 2 * math.pi * (k + 1) / n
			if not (keep(r, ang0) and keep(r, ang1)):
				continue
			p0 = Vector((a * 1.035 * math.cos(ang0), b * 1.035 * math.sin(ang0), z + PLAQUE[1] * 0.3))
			p1 = Vector((a * 1.035 * math.cos(ang1), b * 1.035 * math.sin(ang1), z + PLAQUE[1] * 0.3))
			mid = (p0 + p1) * 0.5
			nrm = Vector((mid.x / a, mid.y / b, 0.0)).normalized()
			plaque(bm, mid, nrm, Vector((0, 0, 1)), ((p1 - p0).length, 0.006, 0.006), 1, 0.0)
# The shoulder guards: rows of plaques hanging over each upper arm, wrapped
# round its outer side, from the shoulder line down.
for s in (-1.0, 1.0):
	a, b = half_axes(SHOULDER)
	arm = Vector((0.0, s * (b + 0.07), SHOULDER * ROW + 0.02))
	for row in range(4):
		for k in range(5):
			ang = math.radians(-64 + k * 32)
			out = Vector((math.sin(ang), s * math.cos(ang), 0.0))
			p = arm + out * 0.1 + Vector((0.0, 0.0, -row * ROW * 0.92))
			plaque(bm, p, out, Vector((0, 0, 1)), PLAQUE, 0, math.radians(-12.0))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
mesh = bpy.data.meshes.new("StoneArmor")
for m in MATS:
	mesh.materials.append(m)
bm.to_mesh(mesh)
bm.free()
ob = bpy.data.objects.new("StoneArmor", mesh)
scene.collection.objects.link(ob)
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_yup=True)
print("built", OUT, len(mesh.polygons), "faces", tuple(round(d, 2) for d in ob.dimensions))
