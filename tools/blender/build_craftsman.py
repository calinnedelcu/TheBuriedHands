# Builds assets/models/characters/craftsman.glb from the jam's craftsman
# (TripoModels/mester-mestesugar-real.glb): a wooden modelling tool in his
# right hand (node "Tool", the game shows it only while he sculpts) and the
# clips the workshop's people use:
#   idle, walk, work_seated, kneel, collapse   - the originals, renamed
#   sculpt   - standing at a clay figure: the left hand steadies it, the
#              right scrapes and shapes with the tool
#   knead    - leaning over a table, pressing clay with both hands
#
#   blender -b --python tools/blender/build_craftsman.py

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig_tools import Rig, rot_from, rot_world, material

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "mester-mestesugar-real.glb")
DST = os.path.join(ROOT, "assets", "models", "characters", "craftsman.glb")

rig = Rig(SRC)
RENAME = {
	"NlaTrack.002_Armature": "idle",
	"NlaTrack_Armature": "walk",
	"NlaTrack.001_Armature": "work_seated",
	"NlaTrack.004_Armature": "kneel",
	"NlaTrack.003_Armature": "collapse",
}
for old, new in RENAME.items():
	bpy.data.actions[old].name = new
	bpy.data.actions[new].use_fake_user = True

# --- The tool: a wooden spatula ---------------------------------------------------------

def build_tool():
	wood = material("ToolWood", (0.36, 0.24, 0.13), 0.0, 0.6)
	mesh = bpy.data.meshes.new("Tool")
	mesh.materials.append(wood)
	bm = bmesh.new()
	# Along the fingers (+y): a round handle through the fist, then a flat blade.
	def ring(y, r, n=8):
		return [bm.verts.new((r * math.cos(a), y, r * math.sin(a))) for a in (2 * math.pi * i / n for i in range(n))]
	rings = [ring(-0.03, 0.0045), ring(0.03, 0.0052)]
	for a, b in zip(rings, rings[1:]):
		for i in range(8):
			bm.faces.new((a[i], a[(i + 1) % 8], b[(i + 1) % 8], b[i]))
	bm.faces.new(list(reversed(rings[0])))
	# Blade: wide and thin, rounded end.
	w, t = 0.011, 0.0015
	pts = [(0.03, -w * 0.6), (0.05, -w), (0.075, -w * 0.9), (0.083, 0.0), (0.075, w * 0.9), (0.05, w), (0.03, w * 0.6)]
	top = [bm.verts.new((x, y, t)) for y, x in pts]
	bot = [bm.verts.new((x, y, -t)) for y, x in pts]
	bm.faces.new(top)
	bm.faces.new(list(reversed(bot)))
	for i in range(len(pts)):
		bm.faces.new((top[i], bot[i], bot[(i + 1) % len(pts)], top[(i + 1) % len(pts)]))
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new("Tool", mesh)
	rig.scene.collection.objects.link(ob)
	return ob


rig.attach(build_tool(), "R")

# --- Poses ------------------------------------------------------------------------------------

def frame_y(y, x_hint):
	"""A hand orientation with its fingers (y) along `y` and its x toward x_hint
	(x is the back of the right hand, the palm of the left)."""
	y = y.normalized()
	x = (x_hint - y * y.dot(x_hint)).normalized()
	return rot_from(x, y, x.cross(y))


def static_base():
	"""The idle's first frame, to build still poses on."""
	rig.arm.animation_data.action = bpy.data.actions["idle"]
	rig.scene.frame_set(0)
	return {pb.name: pb.matrix_basis.copy() for pb in rig.pose}


def restore(base):
	for pb in rig.pose:
		pb.matrix_basis = base[pb.name]
	rig.update()


def lean(deg, head_down=0.0, turn=0.0):
	for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
		rig.turn(bn, rot_world('Z', turn * share) @ rot_world('Y', deg * share))
	rig.turn("Head", rot_world('Y', head_down - deg * 0.5))


def sculpt():
	base = static_base()
	act = bpy.data.actions.new("sculpt")
	act.use_fake_user = True
	rig.arm.animation_data.action = act
	right_rot = frame_y(Vector((0.85, 0.12, -0.5)), Vector((0.0, -0.25, 1.0)))
	# The left hand's x points out of its palm: flat against the figure.
	left_rot = frame_y(Vector((0.15, 0.0, 1.0)), Vector((1.0, 0.0, 0.0)))
	# Four strokes, each: lift to the clay, scrape forward and down, draw back.
	spots = [(0.62, -0.06), (0.6, -0.04), (0.57, -0.075), (0.6, -0.05)]
	for k, (z, y) in enumerate(spots):
		for off, (dx, dz) in ((0, (0.0, 0.0)), (9, (0.035, -0.03)), (15, (0.025, -0.04)), (24, (0.0, 0.0))):
			f = k * 24 + off
			if off == 24 and k < len(spots) - 1:
				continue
			restore(base)
			breath = math.sin(f / 96.0 * 2 * math.pi) * 0.8
			lean(9.0 + breath, head_down=14.0, turn=-4.0)
			rig.solve_arm("R", Vector((0.185 + dx, y, z + dz)), Vector((-0.2, -0.35, 0.45)), right_rot)
			rig.solve_arm("L", Vector((0.2, 0.1, 0.66 + breath * 0.004)), Vector((-0.1, 0.4, 0.5)), left_rot)
			rig.key_all(f)
	# Close the loop on the first pose.
	restore(base)
	lean(9.0, head_down=14.0, turn=-4.0)
	rig.solve_arm("R", Vector((0.185, spots[0][1], spots[0][0])), Vector((-0.2, -0.35, 0.45)), right_rot)
	rig.solve_arm("L", Vector((0.2, 0.1, 0.66)), Vector((-0.1, 0.4, 0.5)), left_rot)
	rig.key_all(96)
	return act


def knead():
	base = static_base()
	act = bpy.data.actions.new("knead")
	act.use_fake_user = True
	rig.arm.animation_data.action = act
	right_rot = frame_y(Vector((1.0, 0.05, -0.35)), Vector((0, 0, 1)))
	left_rot = frame_y(Vector((1.0, -0.05, -0.35)), Vector((0, 0, -1)))
	table = 0.6
	# Left presses while the right lifts, then the other way; 38 frames a cycle.
	keys = {0: (0.0, 1.0), 10: (1.0, 0.0), 19: (1.0, 0.0), 29: (0.0, 1.0), 38: (0.0, 1.0)}
	for f, (left_down, right_down) in keys.items():
		restore(base)
		lean(17.0 + (left_down + right_down) * 1.5, head_down=10.0, turn=(left_down - right_down) * 4.0)
		rig.solve_arm("R", Vector((0.26 + right_down * 0.03, -0.07, table + 0.03 - right_down * 0.025)), Vector((-0.1, -0.4, 0.4)), right_rot)
		rig.solve_arm("L", Vector((0.26 + left_down * 0.03, 0.07, table + 0.03 - left_down * 0.025)), Vector((-0.1, 0.4, 0.4)), left_rot)
		rig.key_all(f)
	return act


made = [bpy.data.actions[n] for n in ("idle", "walk", "work_seated", "kneel", "collapse")]
made.append(sculpt())
made.append(knead())
os.makedirs(os.path.dirname(DST), exist_ok=True)
rig.export(DST, made)
print("built", DST, "with", sorted(a.name for a in made))
