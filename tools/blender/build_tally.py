# Builds the two halves of a tiger tally (hufu, 虎符) into assets/models/props/:
#   tally_left.glb   TallyLeft:  the half Overseer Wei keeps on his desk
#   tally_right.glb  TallyRight: the half the commander of the army pits keeps
# A crouching bronze tiger split down its length, as the Qin tallies were (the
# Du and Xinqi tallies): each half flat inside, rounded outside, a line of
# characters inlaid in gold along its flank. The two fit only each other.
#
#   blender -b --python tools/blender/build_tally.py
#
# Game metres (the world is ~1.6x human scale): about 16 cm long. Blender
# axes: the tiger walks along +x, stands up along +z, and its flat inner face
# is the y = 0 plane; the left half bulges toward +y, the right toward -y.
# Materials are named; the game swaps "Bronze" and "GoldInlay" for its own
# (the inlay is gold that still reads as gold in a dark room).

import bpy, bmesh, math, os, random
from mathutils import Vector, geometry

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "models", "props")

LENGTH = 0.16
# Thickness of a half at its rim and in the middle of the body, and how far
# in from the rim the flank has rounded up to full thickness.
RIM = 0.003
THICK = 0.016
ROUND = 0.009

# The tiger's side, nose to the right: back, head and ears, chest and front
# paw, belly, hind paw, rump, and the tail curling up over it. x along the
# length (0..1), z up, both in lengths.
PROFILE = [
	(0.12, 0.30), (0.20, 0.33), (0.35, 0.34), (0.50, 0.33), (0.62, 0.31), (0.70, 0.34),
	(0.76, 0.40), (0.78, 0.46), (0.81, 0.41), (0.84, 0.45), (0.86, 0.38), (0.92, 0.36),
	(0.99, 0.30), (1.00, 0.26), (0.97, 0.22), (0.90, 0.20), (0.84, 0.17), (0.80, 0.12),
	(0.82, 0.02), (0.86, 0.0), (0.74, 0.0), (0.73, 0.08), (0.66, 0.10), (0.50, 0.11),
	(0.36, 0.10), (0.31, 0.06), (0.31, 0.0), (0.18, 0.0), (0.16, 0.06), (0.10, 0.14),
	(0.07, 0.22), (0.06, 0.27), (0.02, 0.33), (0.03, 0.42), (0.08, 0.45), (0.10, 0.41),
	(0.07, 0.36), (0.10, 0.31),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, color, metallic, roughness):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return m


BRONZE = material("Bronze", (0.5, 0.36, 0.18), 1.0, 0.4)
GOLD = material("GoldInlay", (1.0, 0.77, 0.34), 1.0, 0.22)


def outline():
	"""The profile in metres, centred along its length, its corners rounded
	(two passes of corner cutting, as a casting would have them), every ~2.5 mm."""
	pts = [Vector(((x - 0.5) * LENGTH, z * LENGTH)) for x, z in PROFILE]
	for _ in range(2):
		cut = []
		for i, a in enumerate(pts):
			b = pts[(i + 1) % len(pts)]
			cut += [a.lerp(b, 0.25), a.lerp(b, 0.75)]
		pts = cut
	out = []
	for i, a in enumerate(pts):
		b = pts[(i + 1) % len(pts)]
		n = max(1, int((b - a).length / 0.0025))
		for k in range(n):
			out.append(a.lerp(b, k / n))
	return out


def inside(p, poly):
	hit = False
	j = len(poly) - 1
	for i in range(len(poly)):
		a, b = poly[i], poly[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			hit = not hit
		j = i
	return hit


def rim_distance(p, poly):
	best = 1e9
	for i, a in enumerate(poly):
		b = poly[(i + 1) % len(poly)]
		ab = b - a
		t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
		best = min(best, (a + ab * t - p).length)
	return best


def height(d):
	"""How far the flank stands off the flat face, `d` in from the rim:
	a quarter round from the rim up to full thickness."""
	t = min(d / ROUND, 1.0)
	return RIM + (THICK - RIM) * math.sqrt(1.0 - (1.0 - t) ** 2)


def build_half(name, side, seed):
	poly = outline()
	n = len(poly)
	pts = list(poly)
	xs = [p.x for p in poly]
	zs = [p.y for p in poly]
	step = 0.0032
	x = min(xs) + step * 0.5
	while x < max(xs):
		z = min(zs) + step * 0.5
		while z < max(zs):
			p = Vector((x, z))
			if inside(p, poly) and rim_distance(p, poly) > step * 0.45:
				pts.append(p)
			z += step
		x += step
	edges = [(i, (i + 1) % n) for i in range(n)]
	verts2d, _e, faces, orig_verts, _oe, _of = geometry.delaunay_2d_cdt(pts, edges, [list(range(n))], 1, 1e-7, True)
	bm = bmesh.new()
	outer, inner = [], []
	rim_of = {}
	for j, v in enumerate(verts2d):
		d = rim_distance(v, poly)
		outer.append(bm.verts.new((v.x, side * height(d), v.y)))
		inner.append(bm.verts.new((v.x, 0.0, v.y)))
		for o in orig_verts[j]:
			if o < n:
				rim_of[o] = j
	for f in faces:
		a = bm.faces.new([outer[i] for i in f])
		b = bm.faces.new([inner[i] for i in reversed(f)])
		a.smooth = True
		b.smooth = False
	# The rim: a narrow wall round the outline joining flank and flat face.
	for i in range(n):
		a, b = rim_of[i], rim_of[(i + 1) % n]
		f = bm.faces.new((outer[a], outer[b], inner[b], inner[a]))
		f.smooth = True
	# A closed shell: every face turned outward.
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	# The inscription: a line of characters in gold along the flank, each a
	# few short strokes, where the flank stands at full thickness.
	rnd = random.Random(seed)
	gold_faces = []
	chars = 7
	for c in range(chars):
		cx = -0.042 + c * 0.0085
		cz = 0.0355
		if rim_distance(Vector((cx, cz)), poly) < ROUND + 0.002:
			continue
		for s in range(rnd.randint(3, 5)):
			horizontal = rnd.random() < 0.55
			sx, sz = (0.0042, 0.0007) if horizontal else (0.0007, 0.0042)
			ox = 0.0 if horizontal else rnd.choice((-0.0016, 0.0, 0.0016))
			oz = rnd.choice((-0.0016, 0.0, 0.0016)) if horizontal else 0.0
			gold_faces += stroke(bm, Vector((cx + ox, side * THICK, cz + oz)), sx, sz, side)
	mesh = bpy.data.meshes.new(name)
	mesh.materials.append(BRONZE)
	mesh.materials.append(GOLD)
	for f in gold_faces:
		f.material_index = 1
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new(name, mesh)
	scene.collection.objects.link(ob)
	return ob


def stroke(bm, at, sx, sz, side):
	"""A thin gold bar set into the flank, standing a hair proud of it."""
	vs = []
	for dx in (-sx * 0.5, sx * 0.5):
		for dy in (-0.0004, 0.0007):
			for dz in (-sz * 0.5, sz * 0.5):
				vs.append(bm.verts.new((at.x + dx, at.y + dy * side, at.z + dz)))
	quads = ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))
	faces = []
	for q in quads:
		f = bm.faces.new([vs[i] for i in q])
		faces.append(f)
	bmesh.ops.recalc_face_normals(bm, faces=faces)
	return faces


def export(ob, name):
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
	print("built", path)


left = build_half("TallyLeft", 1.0, 11)
right = build_half("TallyRight", -1.0, 23)
export(left, "tally_left")
export(right, "tally_right")
for ob in (left, right):
	print(ob.name, len(ob.data.polygons), "faces")
