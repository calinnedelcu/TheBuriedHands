# Builds assets/models/characters/apprentice.glb from the jam's apprentice
# (TripoModels/ucenic.glb), its clips named for what they are, plus two new
# ones for after the sealing:
#   talk, point, bow, work, hands_on_hips, walk   - the originals, renamed
#   scared   - standing hunched, arms wrapped round himself, glancing about
#   cower    - sitting curled up, arms round his knees, rocking a little
#
#   blender -b --python tools/blender/build_apprentice.py

import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig_tools import Rig, rot_from, rot_world

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "ucenic.glb")
DST = os.path.join(ROOT, "assets", "models", "characters", "apprentice.glb")

rig = Rig(SRC)
RENAME = {
	"NlaTrack_Armature": "talk",
	"NlaTrack.001_Armature": "point",
	"NlaTrack.002_Armature": "bow",
	"NlaTrack.003_Armature": "work",
	"NlaTrack.005_Armature": "hands_on_hips",
	"NlaTrack.004_Armature": "walk",
}
for old, new in RENAME.items():
	bpy.data.actions[old].name = new
	bpy.data.actions[new].use_fake_user = True


def frame_y(y, x_hint):
	y = y.normalized()
	x = (x_hint - y * y.dot(x_hint)).normalized()
	return rot_from(x, y, x.cross(y))


def base_of(action, frame=0):
	rig.arm.animation_data.action = bpy.data.actions[action]
	rig.scene.frame_set(frame)
	return {pb.name: pb.matrix_basis.copy() for pb in rig.pose}


def restore(base):
	for pb in rig.pose:
		pb.matrix_basis = base[pb.name]
	rig.update()


def scared():
	"""Hunched, hugging himself, the head turning to every sound."""
	base = base_of("talk", 0)
	act = bpy.data.actions.new("scared")
	act.use_fake_user = True
	rig.arm.animation_data.action = act
	# Head yaw (deg) through the loop: a glance one way, back, the other.
	keys = [(0, 0.0, 0.0), (22, 24.0, 0.4), (40, 18.0, 0.6), (62, -20.0, 0.2), (84, -26.0, 0.9), (110, 0.0, 0.0)]
	for f, yaw, shiver in keys:
		restore(base)
		for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
			rig.turn(bn, rot_world('Y', 13.0 * share))
		for side, s in (("L", 1.0), ("R", -1.0)):
			rig.turn(side + "_Clavicle", rot_world('X', 9.0 * s))
		rig.turn("Head", rot_world('Z', yaw) @ rot_world('Y', -6.0))
		# Fists at the opposite upper arms: arms wrapped round the chest.
		chest = 0.62 + shiver * 0.004
		rig.solve_arm("R", Vector((0.11, 0.08, chest)), Vector((0.25, -0.35, 0.5)), frame_y(Vector((-0.2, 1.0, 0.15)), Vector((1.0, 0.0, 0.0))))
		rig.solve_arm("L", Vector((0.1, -0.075, chest - 0.03)), Vector((0.25, 0.35, 0.45)), frame_y(Vector((-0.2, -1.0, 0.15)), Vector((-1.0, 0.0, 0.0))))
		rig.key_all(f)
	return act


def cower():
	"""Curled up where he sits, arms round his knees, rocking."""
	base = base_of("work", 0)
	act = bpy.data.actions.new("cower")
	act.use_fake_user = True
	rig.arm.animation_data.action = act
	restore(base)
	knee_l = rig.pose["L_Calf"].head.copy()
	knee_r = rig.pose["R_Calf"].head.copy()
	keys = [(0, 0.0), (36, 1.0), (72, 0.0), (108, 1.0), (144, 0.0)]
	for f, rock in keys:
		restore(base)
		lean = 26.0 + rock * 7.0
		for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
			rig.turn(bn, rot_world('Y', lean * share))
		rig.turn("Head", rot_world('Y', 18.0 - rock * 4.0))
		mid = (knee_l + knee_r) * 0.5
		# Hands clasped round the shins, just below the knees, in front.
		hold = mid + Vector((0.045, 0.0, -0.06))
		rig.solve_arm("R", hold + Vector((0.0, -0.035, 0.0)), Vector((0.1, -0.4, 0.55)), frame_y(Vector((0.0, 1.0, -0.2)), Vector((1.0, 0.0, 0.0))), follow=False)
		rig.solve_arm("L", hold + Vector((0.0, 0.035, 0.01)), Vector((0.1, 0.4, 0.55)), frame_y(Vector((0.0, -1.0, -0.2)), Vector((1.0, 0.0, 0.0))), follow=False)
		rig.key_all(f)
	return act


made = [bpy.data.actions[n] for n in RENAME.values()]
made.append(scared())
made.append(cower())
os.makedirs(os.path.dirname(DST), exist_ok=True)
rig.export(DST, made)
print("built", DST, "with", sorted(a.name for a in made))
