# Builds the treasury's grave goods, one glTF per prop, into
# assets/models/props/treasure/:
#   ding.glb       bronze tripod cauldron with upright handles
#   hu.glb         lidded bronze wine vessel with ring handles
#   bi.glb         a jade disc on a small stand
#   gold.glb       stacks of gold cakes (bing jin)
#   coins.glb      a heap of ban liang coins (square holes)
#   bianzhong.glb  a rack of seven bronze bells
#   lamp.glb       a tall bronze oil lamp (the game adds the flame)
#
#   blender -b --python tools/blender/build_treasures.py
#
# Sizes are game metres (the world is built at ~1.6x human scale).
# Materials are named; the game swaps "Bronze" for its patina shader.

import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "models", "props", "treasure")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
random.seed(214)


def material(name, color, metallic, roughness):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return m


MATS = {
	"Bronze": material("Bronze", (0.5, 0.36, 0.18), 1.0, 0.4),
	"Gold": material("Gold", (1.0, 0.77, 0.34), 1.0, 0.22),
	"Jade": material("Jade", (0.36, 0.56, 0.42), 0.0, 0.2),
	"LacquerBlack": material("LacquerBlack", (0.03, 0.025, 0.02), 0.0, 0.25),
	"LacquerRed": material("LacquerRed", (0.45, 0.06, 0.04), 0.0, 0.3),
	"Wood": material("Wood", (0.22, 0.13, 0.07), 0.0, 0.7),
}


class Builder:
	"""Collects geometry into one bmesh with a list of materials."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.mats = []

	def mat(self, name):
		if name not in self.mats:
			self.mats.append(name)
		return self.mats.index(name)

	def face(self, verts, mat, smooth=True):
		f = self.bm.faces.new(verts)
		f.material_index = mat
		f.smooth = smooth
		return f

	def lathe(self, profile, segments, mat, xform=Matrix.Identity(4), closed=False, scale_x=1.0, smooth=True):
		"""Revolves (r, z) points about z. r == 0 points become a single pole."""
		m = self.mat(mat)
		rings = []
		for r, z in profile:
			if r <= 1e-6:
				rings.append([self.bm.verts.new(xform @ Vector((0.0, 0.0, z)))])
			else:
				rings.append([self.bm.verts.new(xform @ Vector((r * math.cos(a) * scale_x, r * math.sin(a), z)))
						for a in (2 * math.pi * i / segments for i in range(segments))])
		pairs = list(zip(rings, rings[1:]))
		if closed:
			pairs.append((rings[-1], rings[0]))
		n = segments
		for a, b in pairs:
			if len(a) == 1 and len(b) == 1:
				continue
			if len(a) == 1:
				for i in range(n):
					self.face((a[0], b[(i + 1) % n], b[i]), m, smooth)
			elif len(b) == 1:
				for i in range(n):
					self.face((a[i], a[(i + 1) % n], b[0]), m, smooth)
			else:
				for i in range(n):
					self.face((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]), m, smooth)

	def box(self, size, mat, xform=Matrix.Identity(4)):
		m = self.mat(mat)
		sx, sy, sz = (s * 0.5 for s in size)
		v = [self.bm.verts.new(xform @ Vector((x, y, z))) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
		for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
			self.face([v[i] for i in idx], m, smooth=False)

	def torus(self, major, minor, segs, rings_n, mat, xform=Matrix.Identity(4)):
		m = self.mat(mat)
		grid = []
		for i in range(segs):
			a = 2 * math.pi * i / segs
			row = []
			for j in range(rings_n):
				b = 2 * math.pi * j / rings_n
				r = major + minor * math.cos(b)
				row.append(self.bm.verts.new(xform @ Vector((r * math.cos(a), r * math.sin(a), minor * math.sin(b)))))
			grid.append(row)
		for i in range(segs):
			for j in range(rings_n):
				a, b = grid[i][j], grid[(i + 1) % segs][j]
				c, d = grid[(i + 1) % segs][(j + 1) % rings_n], grid[i][(j + 1) % rings_n]
				self.face((a, b, c, d), m)

	def finish(self):
		mesh = bpy.data.meshes.new(self.name)
		for name in self.mats:
			mesh.materials.append(MATS[name])
		self.bm.normal_update()
		self.bm.to_mesh(mesh)
		self.bm.free()
		ob = bpy.data.objects.new(self.name, mesh)
		scene.collection.objects.link(ob)
		return ob


def export(objects, name):
	bpy.ops.object.select_all(action='DESELECT')
	for ob in objects:
		ob.select_set(True)
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
	print("built", path)


def tilt(axis_deg_x=0.0, axis_deg_y=0.0, at=Vector()):
	return Matrix.Translation(at) @ Matrix.Rotation(math.radians(axis_deg_y), 4, 'Y') @ Matrix.Rotation(math.radians(axis_deg_x), 4, 'X')

# --- Ding --------------------------------------------------------------------------------

def build_ding():
	b = Builder("Ding")
	b.lathe([(0.0, 0.42), (0.18, 0.42), (0.36, 0.47), (0.45, 0.58), (0.48, 0.72), (0.48, 0.88), (0.5, 0.93),
			(0.5, 0.96), (0.46, 0.96), (0.45, 0.9), (0.44, 0.72), (0.4, 0.6), (0.3, 0.51), (0.0, 0.49)], 40, "Bronze")
	# Raised bands round the belly.
	for z in (0.8, 0.66):
		b.lathe([(0.47, z - 0.022), (0.497, z - 0.012), (0.497, z + 0.012), (0.47, z + 0.022)], 40, "Bronze")
	# Three legs, splayed a little, with hoof feet.
	for k in range(3):
		a = 2 * math.pi * k / 3 + math.pi / 2
		at = Vector((0.3 * math.cos(a), 0.3 * math.sin(a), 0.0))
		out = Vector((math.cos(a), math.sin(a), 0.0))
		# Lean the top in toward the bowl's middle.
		rot = Matrix.Rotation(math.radians(7.0), 4, out.cross(Vector((0, 0, 1))).normalized())
		b.lathe([(0.0, 0.0), (0.07, 0.0), (0.075, 0.03), (0.055, 0.08), (0.05, 0.25), (0.062, 0.4), (0.075, 0.47), (0.0, 0.47)],
				16, "Bronze", Matrix.Translation(at) @ rot)
	# Upright handles on the rim.
	for s in (-1, 1):
		x = Matrix.Translation((0.0, s * 0.47, 0.96)) @ Matrix.Rotation(math.radians(-8.0 * s), 4, 'X')
		b.box((0.05, 0.035, 0.22), "Bronze", x @ Matrix.Translation((-0.11, 0.0, 0.1)))
		b.box((0.05, 0.035, 0.22), "Bronze", x @ Matrix.Translation((0.11, 0.0, 0.1)))
		b.box((0.27, 0.035, 0.05), "Bronze", x @ Matrix.Translation((0.0, 0.0, 0.2)))
	return b.finish()

# --- Hu ----------------------------------------------------------------------------------

def build_hu():
	b = Builder("Hu")
	b.lathe([(0.0, 0.0), (0.17, 0.0), (0.18, 0.03), (0.16, 0.07), (0.24, 0.2), (0.3, 0.38), (0.29, 0.52), (0.22, 0.64),
			(0.14, 0.74), (0.13, 0.86), (0.16, 0.94), (0.165, 0.965), (0.15, 0.965), (0.12, 0.87), (0.0, 0.85)], 36, "Bronze")
	b.lathe([(0.0, 0.955), (0.162, 0.958), (0.155, 0.99), (0.1, 1.025), (0.045, 1.04), (0.05, 1.08), (0.03, 1.1), (0.0, 1.1)],
			36, "Bronze")
	for z in (0.44, 0.3):
		b.lathe([(0.29, z - 0.018), (0.305, z - 0.009), (0.305, z + 0.009), (0.29, z + 0.018)], 36, "Bronze")
	# Ring handles hanging from masks on the shoulders.
	for s in (-1, 1):
		b.box((0.05, 0.06, 0.06), "Bronze", Matrix.Translation((0.0, s * 0.265, 0.58)))
		b.torus(0.06, 0.011, 18, 6, "Bronze", Matrix.Translation((0.0, s * 0.3, 0.5)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
	return b.finish()

# --- Bi ----------------------------------------------------------------------------------

def build_bi():
	b = Builder("Bi")
	# A thick jade ring standing up, held in a wooden stand.
	up = Matrix.Translation((0.0, 0.0, 0.31)) @ Matrix.Rotation(math.pi / 2, 4, 'X')
	b.lathe([(0.07, -0.016), (0.225, -0.016), (0.232, 0.0), (0.225, 0.016), (0.07, 0.016), (0.064, 0.0)], 48, "Jade", up, closed=True)
	b.box((0.42, 0.14, 0.06), "Wood", Matrix.Translation((0.0, 0.0, 0.03)))
	for s in (-1, 1):
		b.box((0.035, 0.05, 0.16), "Wood", Matrix.Translation((s * 0.15, 0.0, 0.13)))
	return b.finish()

# --- Gold cakes ----------------------------------------------------------------------------

def build_gold():
	b = Builder("Gold")
	cake = [(0.0, 0.0), (0.06, 0.0), (0.063, 0.012), (0.056, 0.021), (0.03, 0.016), (0.0, 0.015)]
	for cx, cy, n in ((0.0, 0.0, 7), (0.16, 0.05, 5), (-0.06, 0.15, 3)):
		for i in range(n):
			x = Matrix.Translation((cx + random.uniform(-0.008, 0.008), cy + random.uniform(-0.008, 0.008), i * 0.021)) @ \
				Matrix.Rotation(random.uniform(-0.04, 0.04), 4, 'X')
			b.lathe(cake, 20, "Gold", x)
	for i in range(6):
		a = random.uniform(0, 2 * math.pi)
		r = random.uniform(0.18, 0.3)
		x = Matrix.Translation((r * math.cos(a), r * math.sin(a), 0.0)) @ Matrix.Rotation(random.uniform(-0.3, 0.3), 4, 'X')
		b.lathe(cake, 20, "Gold", x)
	return b.finish()

# --- Coins ---------------------------------------------------------------------------------

def coin(b, xform, mat):
	"""A ban liang: round, with a square hole."""
	m = b.mat(mat)
	r, hole, t = 0.026, 0.0075, 0.0022
	outer = [Vector((r * math.cos(a), r * math.sin(a), 0.0)) for a in (2 * math.pi * i / 8 for i in range(8))]
	inner = [Vector((hole * x, hole * y, 0.0)) for x, y in ((1, 0), (0, 1), (-1, 0), (0, -1))]
	inner = [Matrix.Rotation(math.pi / 4, 3, 'Z') @ v * 1.41 for v in inner]
	top_o = [b.bm.verts.new(xform @ (v + Vector((0, 0, t)))) for v in outer]
	bot_o = [b.bm.verts.new(xform @ (v - Vector((0, 0, t)))) for v in outer]
	top_i = [b.bm.verts.new(xform @ (v + Vector((0, 0, t)))) for v in inner]
	bot_i = [b.bm.verts.new(xform @ (v - Vector((0, 0, t)))) for v in inner]
	# Each square side faces two octagon edges.
	for k in range(4):
		o0, o1, o2 = (2 * k) % 8, (2 * k + 1) % 8, (2 * k + 2) % 8
		i0, i1 = k, (k + 1) % 4
		b.face((top_o[o0], top_o[o1], top_i[i0]), m, False)
		b.face((top_o[o1], top_o[o2], top_i[i1], top_i[i0]), m, False)
		b.face((bot_o[o1], bot_o[o0], bot_i[i0]), m, False)
		b.face((bot_o[o2], bot_o[o1], bot_i[i0], bot_i[i1]), m, False)
	for k in range(8):
		b.face((bot_o[k], bot_o[(k + 1) % 8], top_o[(k + 1) % 8], top_o[k]), m, False)
	for k in range(4):
		b.face((top_i[k], top_i[(k + 1) % 4], bot_i[(k + 1) % 4], bot_i[k]), m, False)


def build_coins():
	b = Builder("Coins")
	# A heap: coins scattered in a low cone, lying mostly flat.
	for i in range(760):
		r = 0.4 * math.sqrt(random.random())
		a = random.uniform(0, 2 * math.pi)
		h = max(0.0, 0.3 * (1.0 - r / 0.4) ** 1.3) * random.uniform(0.8, 1.0)
		x = Matrix.Translation((r * math.cos(a), r * math.sin(a), h + 0.003)) @ \
			Matrix.Rotation(random.uniform(0, 2 * math.pi), 4, 'Z') @ Matrix.Rotation(random.uniform(-0.5, 0.5), 4, 'X')
		coin(b, x, "Bronze")
	# A few strings of coins on cords, the way they were kept.
	for k in range(3):
		at = Vector((0.5 + k * 0.08, -0.25 + k * 0.17, 0.028))
		turn = random.uniform(0, math.pi)
		for i in range(14):
			x = Matrix.Translation(at + Vector((math.cos(turn), math.sin(turn), 0)) * (i * 0.0058 - 0.04)) @ \
				Matrix.Rotation(turn, 4, 'Z') @ Matrix.Rotation(math.pi / 2, 4, 'Y')
			coin(b, x, "Bronze")
	return b.finish()

# --- Bianzhong --------------------------------------------------------------------------

BELL_PROFILE = [(0.0, 1.0), (0.3, 1.0), (0.335, 0.86), (0.37, 0.62), (0.41, 0.34), (0.45, 0.06), (0.46, 0.0),
		(0.42, 0.0), (0.4, 0.3), (0.35, 0.62), (0.28, 0.93), (0.0, 0.95)]


def bell(b, height, at):
	x = Matrix.Translation(at) @ Matrix.Scale(height, 4)
	b.lathe(BELL_PROFILE, 28, "Bronze", x, scale_x=0.72)
	# The hanging loop.
	b.torus(0.09 * height, 0.022 * height, 14, 6, "Bronze", Matrix.Translation(at + Vector((0, 0, height * 1.08))) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
	# Bosses (mei) in rows on both faces.
	stud = [(0.0, 0.0), (0.035, 0.0), (0.03, 0.03), (0.0, 0.05)]
	for face in (-1, 1):
		for row in range(3):
			for col in range(3):
				z = 0.86 - row * 0.1
				r = 0.335 + (0.86 - z) * 0.15
				ang = math.radians((col - 1) * 22.0)
				p = Vector((math.sin(ang) * r * 0.72 * 1.02, face * math.cos(ang) * r * 1.0, z))
				n = Vector((math.sin(ang) * 0.72, face * math.cos(ang), 0.0)).normalized()
				rot = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
				b.lathe(stud, 6, "Bronze", x @ Matrix.Translation(p) @ rot, smooth=False)


def build_bianzhong():
	b = Builder("Bianzhong")
	width, height = 4.2, 2.3
	for s in (-1, 1):
		b.box((0.4, 0.4, 0.16), "LacquerBlack", Matrix.Translation((s * width * 0.45, 0.0, 0.08)))
		b.box((0.13, 0.13, height), "LacquerBlack", Matrix.Translation((s * width * 0.45, 0.0, height * 0.5)))
		for z in (0.5, 1.4, 2.0):
			b.box((0.14, 0.14, 0.05), "LacquerRed", Matrix.Translation((s * width * 0.45, 0.0, z)))
	b.box((width + 0.3, 0.17, 0.2), "LacquerBlack", Matrix.Translation((0.0, 0.0, height)))
	b.box((width + 0.36, 0.18, 0.04), "LacquerRed", Matrix.Translation((0.0, 0.0, height - 0.08)))
	# Bronze end caps on the beam.
	for s in (-1, 1):
		b.box((0.12, 0.2, 0.24), "Bronze", Matrix.Translation((s * (width * 0.5 + 0.17), 0.0, height)))
	sizes = [0.62, 0.56, 0.5, 0.45, 0.41, 0.37, 0.34]
	span = width * 0.72
	for i, h in enumerate(sizes):
		x = -span * 0.5 + span * i / (len(sizes) - 1)
		top = height - 0.1
		hook = 0.12
		b.box((0.025, 0.025, hook), "Bronze", Matrix.Translation((x, 0.0, top - hook * 0.5)))
		bell(b, h, Vector((x, 0.0, top - hook - h * 1.08 - 0.02)))
	return b.finish()


# --- Standing lamp -----------------------------------------------------------------------

def build_lamp():
	"""A tall bronze lamp: spreading foot, stem with knots, a shallow oil dish."""
	b = Builder("BronzeLamp")
	b.lathe([(0.0, 0.0), (0.24, 0.0), (0.25, 0.03), (0.2, 0.07), (0.1, 0.13), (0.05, 0.2), (0.045, 0.6), (0.075, 0.64),
			(0.075, 0.68), (0.04, 0.72), (0.035, 1.25), (0.065, 1.29), (0.065, 1.32), (0.04, 1.36), (0.045, 1.42),
			(0.2, 1.46), (0.215, 1.5), (0.19, 1.5), (0.17, 1.47), (0.0, 1.46)], 28, "Bronze")
	return b.finish()


export([build_lamp()], "lamp")
export([build_ding()], "ding")
export([build_hu()], "hu")
export([build_bi()], "bi")
export([build_gold()], "gold")
export([build_coins()], "coins")
export([build_bianzhong()], "bianzhong")
