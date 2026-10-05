# Builds the miniature cities set on the Mercury Hall's map of the empire
# ("palaces and towers for the hundred officials", Sima Qian), into
# assets/models/props/miniatures/:
#   palace.glb  a hall on a stepped earthen terrace, double-eaved hip roof
#   tower.glb   a watchtower (que) in three storeys
#   city.glb    a walled city: rammed-earth walls, gate towers, a hall inside
# Bronze bodies, gilded roofs (the game swaps "Bronze" for its patina shader).
# Units: 1 = one metre of the game at scale 1 (they are placed scaled up).
#
#   blender -b --python tools/blender/build_miniatures.py

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig_tools import material

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "models", "props", "miniatures")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = {
	"Bronze": material("Bronze", (0.5, 0.36, 0.18), 1.0, 0.4),
	"Gold": material("Gold", (1.0, 0.77, 0.34), 1.0, 0.22),
	"Earth": material("Earth", (0.42, 0.33, 0.22), 0.0, 0.9),
}


class B:
	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.mats = []

	def m(self, name):
		if name not in self.mats:
			self.mats.append(name)
		return self.mats.index(name)

	def quad(self, vs, mat):
		f = self.bm.faces.new([self.bm.verts.new(v) for v in vs])
		f.material_index = self.m(mat)
		return f

	def box(self, c, size, mat):
		x, y, z = c
		sx, sy, sz = (s * 0.5 for s in size)
		v = [Vector((x + a * sx, y + b * sy, z + d * sz)) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
		for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
			self.quad([v[i] for i in idx], mat)

	def frustum(self, c, bottom, top, height, mat):
		"""A box narrowing upward (terraces, tower bodies): bottom/top = (x, y) sizes."""
		x, y, z = c
		bx, by = bottom[0] * 0.5, bottom[1] * 0.5
		tx, ty = top[0] * 0.5, top[1] * 0.5
		b = [Vector((x + sx * bx, y + sy * by, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
		t = [Vector((x + sx * tx, y + sy * ty, z + height)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
		for i in range(4):
			self.quad([b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i]], mat)
		self.quad(list(reversed(b)), mat)
		self.quad(t, mat)

	def hip_roof(self, c, size, height, overhang, lift, mat):
		"""A hip roof whose eaves sweep up at the corners (by `lift`); the
		ridge runs along x when the roof is longer that way."""
		x, y, z = c
		ex, ey = size[0] * 0.5 + overhang, size[1] * 0.5 + overhang
		ridge = max(size[0] - size[1], 0.0) * 0.5
		c00 = Vector((x - ex, y - ey, z + lift))
		c10 = Vector((x + ex, y - ey, z + lift))
		c11 = Vector((x + ex, y + ey, z + lift))
		c01 = Vector((x - ex, y + ey, z + lift))
		m_s = Vector((x, y - ey, z))
		m_e = Vector((x + ex, y, z))
		m_n = Vector((x, y + ey, z))
		m_w = Vector((x - ex, y, z))
		r0 = Vector((x - ridge, y, z + height))
		r1 = Vector((x + ridge, y, z + height))
		tris = [(c00, m_s, r0), (m_s, c10, r1), (c11, m_n, r1), (m_n, c01, r0),
				(c10, m_e, r1), (m_e, c11, r1), (c01, m_w, r0), (m_w, c00, r0)]
		if ridge > 1e-4:
			tris += [(m_s, r1, r0), (m_n, r0, r1)]
		# The underside, so the eaves read from below.
		mid = Vector((x, y, z))
		ring = [c00, m_s, c10, m_e, c11, m_n, c01, m_w]
		for i in range(8):
			tris.append((ring[(i + 1) % 8], ring[i], mid))
		for t in tris:
			self.quad(list(t), mat)

	def finish(self):
		mesh = bpy.data.meshes.new(self.name)
		for n in self.mats:
			mesh.materials.append(MATS[n])
		bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
		self.bm.to_mesh(mesh)
		self.bm.free()
		ob = bpy.data.objects.new(self.name, mesh)
		scene.collection.objects.link(ob)
		return ob


def hall(b, c, w, d, h, roofs=2):
	"""A hall: bronze body with gilded double-eaved roof, on its own floor."""
	x, y, z = c
	b.box((x, y, z + h * 0.5), (w, d, h), "Bronze")
	# Columns: thin proud strips along the front.
	n = max(3, int(w / 0.18))
	for i in range(n):
		px = x - w * 0.5 + w * (i + 0.5) / n
		b.box((px, y - d * 0.5 - 0.012, z + h * 0.5), (0.03, 0.024, h), "Gold")
	roof_z = z + h
	b.hip_roof((x, y, roof_z), (w, d), d * 0.45, d * 0.25, d * 0.12, "Gold")
	if roofs > 1:
		b.box((x, y, roof_z + d * 0.3), (w * 0.7, d * 0.6, d * 0.12), "Bronze")
		b.hip_roof((x, y, roof_z + d * 0.36), (w * 0.7, d * 0.6), d * 0.4, d * 0.2, d * 0.1, "Gold")


def palace():
	b = B("Palace")
	b.frustum((0, 0, 0), (2.0, 1.5), (1.8, 1.3), 0.18, "Earth")
	b.frustum((0, 0, 0.18), (1.6, 1.1), (1.45, 0.95), 0.16, "Earth")
	# Steps up the front.
	for i in range(4):
		b.box((0, -0.66 - i * 0.05, 0.03 + i * 0.075), (0.3, 0.1, 0.06), "Earth")
	hall(b, (0, 0, 0.34), 1.1, 0.62, 0.36)
	return b.finish()


def tower():
	b = B("Tower")
	b.frustum((0, 0, 0), (0.55, 0.55), (0.45, 0.45), 0.6, "Earth")
	z = 0.6
	for i, (w, h) in enumerate(((0.42, 0.28), (0.34, 0.24), (0.26, 0.2))):
		b.box((0, 0, z + h * 0.5), (w, w, h), "Bronze")
		b.hip_roof((0, 0, z + h), (w, w), w * 0.42, w * 0.3, w * 0.12, "Gold")
		z += h + w * 0.18
	return b.finish()


def city():
	b = B("City")
	side, wall_h, wall_t = 2.6, 0.24, 0.16
	half = side * 0.5
	for sx, sy, lx, ly in ((0, -half, side, wall_t), (0, half, side, wall_t), (-half, 0, wall_t, side), (half, 0, wall_t, side)):
		b.frustum((sx, sy, 0), (lx + 0.04, ly + 0.04), (lx, ly), wall_h, "Earth")
	# Corner towers and gate towers.
	for sx in (-half, half):
		for sy in (-half, half):
			b.box((sx, sy, wall_h + 0.08), (0.26, 0.26, 0.16), "Bronze")
			b.hip_roof((sx, sy, wall_h + 0.16), (0.26, 0.26), 0.12, 0.06, 0.03, "Gold")
	for gx, gy, rot in ((0, -half, 0), (0, half, 0), (-half, 0, 1), (half, 0, 1)):
		w, d = (0.6, 0.26) if rot == 0 else (0.26, 0.6)
		b.box((gx, gy, wall_h + 0.11), (w, d, 0.22), "Bronze")
		b.hip_roof((gx, gy, wall_h + 0.22), (w, d), min(w, d) * 0.6, 0.07, 0.03, "Gold")
	# The governor's hall in the middle, a smaller one beside it.
	b.frustum((0, 0.2, 0), (0.95, 0.65), (0.85, 0.55), 0.1, "Earth")
	hall(b, (0, 0.2, 0.1), 0.7, 0.4, 0.24)
	hall(b, (-0.6, -0.55, 0), 0.4, 0.28, 0.18, roofs=1)
	hall(b, (0.62, -0.5, 0), 0.4, 0.28, 0.18, roofs=1)
	return b.finish()


def export(ob, name):
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
	print("built", path)


export(palace(), "palace")
export(tower(), "tower")
export(city(), "city")
