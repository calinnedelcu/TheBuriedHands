# Builds assets/models/props/crossbow.glb: a Qin crossbow (nu) for the wall
# traps - a stock with its groove, a recurved lacquered prod, the bronze
# trigger box (guo) with its hanging lever, a cocked string drawn back to
# the nut, and a bolt in the groove. Objects "String" and "Bolt" are shown
# or hidden by the game (fired, disarmed).
# Godot axes: forward (where it shoots) is -z, up is +y; in Blender forward
# is +y and up is +z (the glTF export converts).
#
#   blender -b --python tools/blender/build_crossbow.py

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig_tools import material

ROOT = os.path.dirname(os.path.dirname(HERE))
DST = os.path.join(ROOT, "assets", "models", "props", "crossbow.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = {
	"Wood": material("Wood", (0.26, 0.16, 0.09), 0.0, 0.75),
	"LacquerBlack": material("LacquerBlack", (0.04, 0.03, 0.025), 0.0, 0.3),
	"LacquerRed": material("LacquerRed", (0.42, 0.07, 0.04), 0.0, 0.35),
	"Bronze": material("Bronze", (0.5, 0.36, 0.18), 1.0, 0.4),
	"Cord": material("Cord", (0.72, 0.64, 0.5), 0.0, 0.9),
}


def obj(name, build):
	bm = bmesh.new()
	mats = []

	def mat(n):
		if n not in mats:
			mats.append(n)
		return mats.index(n)

	build(bm, mat)
	mesh = bpy.data.meshes.new(name)
	for n in mats:
		mesh.materials.append(MATS[n])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new(name, mesh)
	scene.collection.objects.link(ob)
	return ob


def box(bm, m, centre, size, rot=Matrix.Identity(3)):
	cx, cy, cz = centre
	sx, sy, sz = (s * 0.5 for s in size)
	vs = []
	for a in (-1, 1):
		for b in (-1, 1):
			for c in (-1, 1):
				vs.append(bm.verts.new(Vector((cx, cy, cz)) + rot @ Vector((a * sx, b * sy, c * sz))))
	for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
		f = bm.faces.new([vs[i] for i in idx])
		f.material_index = m
	return vs


def tube(bm, m, points, radius, sides=6):
	"""A tube through `points` (a polyline)."""
	rings = []
	for i, p in enumerate(points):
		d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
		side = d.cross(Vector((0, 0, 1)))
		if side.length < 1e-3:
			side = d.cross(Vector((1, 0, 0)))
		side.normalize()
		up = side.cross(d).normalized()
		rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radius) for a in (2 * math.pi * k / sides for k in range(sides))])
	for a, b in zip(rings, rings[1:]):
		for k in range(sides):
			f = bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
			f.material_index = m
			f.smooth = True
	for ring in (rings[0], rings[-1]):
		f = bm.faces.new(ring)
		f.material_index = m


PROD_Y = 0.3     # where the prod crosses the stock (Blender +y = forward)
NUT_Y = -0.22    # where the string is held by the trigger


def build_stock(bm, mat):
	wood = mat("Wood")
	# The stock: a long beam, thicker at the back, with the groove on top.
	box(bm, wood, (0, -0.05, 0), (0.1, 0.92, 0.08))
	box(bm, wood, (0, -0.42, -0.03), (0.12, 0.2, 0.12))
	box(bm, mat("LacquerRed"), (0, 0.32, 0.0), (0.104, 0.06, 0.084))
	# Groove rails.
	for x in (-0.03, 0.03):
		box(bm, wood, (x, 0.0, 0.045), (0.018, 0.78, 0.012))


def build_prod(bm, mat):
	lac = mat("LacquerBlack")
	pts = []
	for i in range(-10, 11):
		t = i / 10.0
		x = t * 0.56
		# Arms sweep back from the centre, then the tips recurve forward.
		y = PROD_Y - 0.13 * t * t + 0.05 * max(0.0, abs(t) - 0.8) / 0.2
		pts.append(Vector((x, y, 0.0)))
	tube(bm, lac, pts, 0.018, 8)
	# Bronze fittings at the tips and the binding at the centre.
	for x in (-0.555, 0.555):
		box(bm, mat("Bronze"), (x, PROD_Y - 0.13 + 0.05, 0.0), (0.03, 0.04, 0.03))
	box(bm, mat("Cord"), (0, PROD_Y, 0.0), (0.12, 0.05, 0.05))


def build_trigger(bm, mat):
	bronze = mat("Bronze")
	# The guo: a bronze box set in the stock, the nut (wangshan) standing
	# up to hold the string, the lever hanging below.
	box(bm, bronze, (0, NUT_Y, 0.0), (0.07, 0.14, 0.1))
	box(bm, bronze, (0, NUT_Y + 0.02, 0.07), (0.04, 0.025, 0.06))
	box(bm, bronze, (0, NUT_Y - 0.03, -0.11), (0.025, 0.03, 0.14), Matrix.Rotation(math.radians(12), 3, 'X'))


def build_string(bm, mat):
	cord = mat("Cord")
	tip_y = PROD_Y - 0.13 + 0.05
	for x in (-0.55, 0.55):
		tube(bm, cord, [Vector((x, tip_y, 0.0)), Vector((0.0, NUT_Y + 0.03, 0.05))], 0.004, 4)


def build_bolt(bm, mat):
	wood = mat("Wood")
	tube(bm, wood, [Vector((0, NUT_Y + 0.02, 0.06)), Vector((0, 0.52, 0.06))], 0.009, 6)
	# Bronze head, three-edged as Qin arrowheads were.
	b = mat("Bronze")
	tip = Vector((0, 0.62, 0.06))
	base = [Vector((0.016 * math.cos(a), 0.52, 0.06 + 0.016 * math.sin(a))) for a in (math.pi / 2 + 2 * math.pi * k / 3 for k in range(3))]
	vt = bm.verts.new(tip)
	vb = [bm.verts.new(v) for v in base]
	for k in range(3):
		f = bm.faces.new((vb[k], vb[(k + 1) % 3], vt))
		f.material_index = b
	f = bm.faces.new(list(reversed(vb)))
	f.material_index = b
	# Fletching.
	f2 = mat("Cord")
	for a in (0.0, math.pi * 2 / 3, math.pi * 4 / 3):
		r = Matrix.Rotation(a, 3, 'Y')
		box(bm, f2, (0, NUT_Y + 0.1, 0.06), (0.002, 0.1, 0.03), r)


parts = [obj("Stock", build_stock), obj("Prod", build_prod), obj("Trigger", build_trigger),
		obj("String", build_string), obj("Bolt", build_bolt)]
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
	p.select_set(True)
os.makedirs(os.path.dirname(DST), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print("built", DST)
