# Builds assets/models/characters/liang.glb from the jam's engineer
# (TripoModels/monk.glb). He talks from where he sits, so his speaking clips
# are made seated, on his own sitting pose:
#   sit                 - the original: thinking, chin on hand
#   talk                - seated, the right hand explaining, the head nodding
#   surprised           - seated, leaning back, both hands lifting
#   frustrated          - seated, a hand rubbing his brow
#   stand_talk, stand_frustrated - the original standing clips, renamed
#
#   blender -b --python tools/blender/build_liang.py

import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig_tools import Rig, rot_from, rot_world

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "monk.glb")
DST = os.path.join(ROOT, "assets", "models", "characters", "liang.glb")

rig = Rig(SRC)
RENAME = {
	"NlaTrack.001_Armature": "sit",
	"NlaTrack.002_Armature": "stand_talk",
	"NlaTrack_Armature": "stand_frustrated",
}
for old, new in RENAME.items():
	bpy.data.actions[old].name = new
	bpy.data.actions[new].use_fake_user = True


def frame_y(y, x_hint):
	y = y.normalized()
	x = (x_hint - y * y.dot(x_hint)).normalized()
	return rot_from(x, y, x.cross(y))


# The seated base: the sitting clip's first frame (hands on his knees).
rig.arm.animation_data.action = bpy.data.actions["sit"]
rig.scene.frame_set(0)
BASE = {pb.name: pb.matrix_basis.copy() for pb in rig.pose}
REST_LEFT = rig.pose["L_Hand"].matrix.copy()


def restore():
	for pb in rig.pose:
		pb.matrix_basis = BASE[pb.name]
	rig.update()


def seated(name, keys):
	"""keys: frame -> dict(lean, head_yaw, head_pitch, right=(fist, pole, rot) or None, left=...)."""
	act = bpy.data.actions.new(name)
	act.use_fake_user = True
	rig.arm.animation_data.action = act
	for f in sorted(keys):
		k = keys[f]
		restore()
		lean = k.get("lean", 0.0)
		for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
			rig.turn(bn, rot_world('Y', lean * share))
		rig.turn("Head", rot_world('Z', k.get("yaw", 0.0)) @ rot_world('Y', k.get("pitch", 0.0) - lean * 0.5))
		if k.get("right"):
			rig.solve_arm("R", *k["right"])
		if k.get("left"):
			rig.solve_arm("L", *k["left"])
		rig.key_all(f)
	return act


# An open hand, palm up and a little in, explaining.
EXPLAIN = frame_y(Vector((0.9, -0.15, 0.1)), Vector((0.0, 0.3, -1.0)))
POLE_R = Vector((-0.15, -0.4, 0.45))
POLE_L = Vector((-0.15, 0.4, 0.45))

talk = seated("talk", {
	0: {"lean": 6, "pitch": 0, "right": (Vector((0.16, -0.12, 0.55)), POLE_R, EXPLAIN)},
	10: {"lean": 8, "pitch": 6, "right": (Vector((0.2, -0.1, 0.6)), POLE_R, EXPLAIN)},
	22: {"lean": 6, "pitch": -2, "yaw": 6, "right": (Vector((0.18, -0.15, 0.57)), POLE_R, EXPLAIN)},
	34: {"lean": 9, "pitch": 7, "right": (Vector((0.22, -0.08, 0.62)), POLE_R, EXPLAIN)},
	48: {"lean": 6, "pitch": 0, "right": (Vector((0.16, -0.12, 0.55)), POLE_R, EXPLAIN)},
})

surprised = seated("surprised", {
	0: {"lean": 0},
	8: {"lean": -10, "pitch": -8,
		"right": (Vector((0.14, -0.2, 0.66)), POLE_R, frame_y(Vector((0.2, -0.3, 1.0)), Vector((1.0, 0.0, 0.0)))),
		"left": (Vector((0.14, 0.2, 0.66)), POLE_L, frame_y(Vector((0.2, 0.3, 1.0)), Vector((-1.0, 0.0, 0.0))))},
	30: {"lean": -8, "pitch": -6,
		"right": (Vector((0.14, -0.19, 0.64)), POLE_R, frame_y(Vector((0.2, -0.3, 1.0)), Vector((1.0, 0.0, 0.0)))),
		"left": (Vector((0.14, 0.19, 0.64)), POLE_L, frame_y(Vector((0.2, 0.3, 1.0)), Vector((-1.0, 0.0, 0.0))))},
	48: {"lean": 0},
})

# Rubbing his brow: the right hand at the forehead, moving a little.
BROW = Vector((0.1, -0.02, 0.8))
frustrated = seated("frustrated", {
	0: {"lean": 14, "pitch": 14, "right": (BROW, POLE_R, frame_y(Vector((-0.1, 1.0, 0.3)), Vector((1.0, 0.0, 0.0))))},
	14: {"lean": 15, "pitch": 16, "right": (BROW + Vector((0.0, 0.03, 0.0)), POLE_R, frame_y(Vector((-0.1, 1.0, 0.3)), Vector((1.0, 0.0, 0.0))))},
	28: {"lean": 14, "pitch": 14, "right": (BROW, POLE_R, frame_y(Vector((-0.1, 1.0, 0.3)), Vector((1.0, 0.0, 0.0))))},
})

made = [bpy.data.actions[n] for n in RENAME.values()] + [talk, surprised, frustrated]
os.makedirs(os.path.dirname(DST), exist_ok=True)
rig.export(DST, made)
print("built", DST, "with", sorted(a.name for a in made))
