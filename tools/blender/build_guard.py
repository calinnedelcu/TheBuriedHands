# Builds assets/models/characters/qin_guard.glb from the jam's guard model
# (TripoModels/samurai.glb): a bronze ji (dagger-axe) in the right hand, a
# grip for the torch in the left, and the animation set the guards use:
#   idle, idle_alt, walk, run, talk   - the originals, the right arm now
#                                       holding the ji (torch_* variants also
#                                       hold the torch up in the left hand)
#   ready, advance                    - halberd levelled, watching / walking
#   attack                            - a thrust (the hit lands at 0.45 s)
#
#   blender -b --python tools/blender/build_guard.py
#
# Arms are posed with an analytic two-bone IK on top of each source frame;
# targets are given in the model's rest frame (x forward, y left, z up,
# model units: the figure is 0.88 tall) and follow the chest.

import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "TripoModels", "samurai.glb")
DST = os.path.join(ROOT, "assets", "models", "characters", "qin_guard.glb")

BASE = {
	"idle": "NlaTrack.003_Armature",
	"idle_alt": "NlaTrack.004_Armature",
	"walk": "NlaTrack.002_Armature.001",
	"run": "NlaTrack_Armature.001",
	"talk": "NlaTrack.002_Armature",
}

# --- Scene ---------------------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene = bpy.context.scene
scene.render.fps = 24
for ob in list(bpy.data.objects):
	if ob.name.startswith("Icosphere"):
		bpy.data.objects.remove(ob, do_unlink=True)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
body = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm][0]
bones = arm.data.bones
pose = arm.pose.bones
bpy.context.view_layer.objects.active = arm
arm.animation_data.action = None
for t in list(arm.animation_data.nla_tracks):
	arm.animation_data.nla_tracks.remove(t)


def rest_head(name):
	return bones[name].head_local.copy()


SHOULDER_LEN = {s: (rest_head(s + "_Forearm") - rest_head(s + "_Upperarm")).length for s in "RL"}
FOREARM_LEN = {s: (rest_head(s + "_Hand") - rest_head(s + "_Forearm")).length for s in "RL"}
CHEST_REST = bones["Spine02"].matrix_local.copy()

# --- The ji ------------------------------------------------------------------------------

def material(name, color, metallic, roughness):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return m


BRONZE = material("JiBronze", (0.55, 0.38, 0.17), 1.0, 0.36)
SHAFT = material("JiShaft", (0.07, 0.045, 0.035), 0.0, 0.5)
BINDING = material("JiBinding", (0.42, 0.05, 0.03), 0.0, 0.55)


def ring(bm, z, r, n, mat_index):
	return [bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in (2 * math.pi * i / n for i in range(n))]


def tube(bm, stations, n, mat_index, cap_bottom=True, cap_top=True):
	"""Loft of circles: stations = [(z, radius), ...]."""
	rings = [ring(bm, z, r, n, mat_index) for z, r in stations]
	for a, b in zip(rings, rings[1:]):
		for i in range(n):
			f = bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
			f.material_index = mat_index
			f.smooth = True
	if cap_bottom:
		f = bm.faces.new(list(reversed(rings[0])))
		f.material_index = mat_index
	if cap_top:
		f = bm.faces.new(rings[-1])
		f.material_index = mat_index


def blade(bm, stations, mat_index):
	"""Leaf blade along +z with a diamond section: stations = [(z, half width, half ridge)]."""
	secs = []
	for z, w, t in stations:
		secs.append([bm.verts.new((w, 0, z)), bm.verts.new((0, t, z)), bm.verts.new((-w, 0, z)), bm.verts.new((0, -t, z))])
	for a, b in zip(secs, secs[1:]):
		for i in range(4):
			f = bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
			f.material_index = mat_index
	f = bm.faces.new(list(reversed(secs[0])))
	f.material_index = mat_index


def plate(bm, outline, half_thick, mat_index):
	"""A flat plate in the yz plane from a 2D outline [(y, z)], thickness along x."""
	front = [bm.verts.new((half_thick, y, z)) for y, z in outline]
	back = [bm.verts.new((-half_thick, y, z)) for y, z in outline]
	n = len(outline)
	f1 = bm.faces.new(front)
	f2 = bm.faces.new(list(reversed(back)))
	for f in (f1, f2):
		f.material_index = mat_index
	for i in range(n):
		f = bm.faces.new((front[i], back[i], back[(i + 1) % n], front[(i + 1) % n]))
		f.material_index = mat_index


LENGTH = 0.92   # whole weapon, model units (about 3 m in the game)
GRIP = 0.5      # from the butt to the fist


def build_ji():
	mesh = bpy.data.meshes.new("Ji")
	for m in (SHAFT, BRONZE, BINDING):
		mesh.materials.append(m)
	bm = bmesh.new()
	bottom = -GRIP
	top = LENGTH - GRIP - 0.09
	tube(bm, [(bottom + 0.02, 0.0092), (top, 0.0082)], 10, 0, cap_bottom=False)
	# Bronze butt cap and the socket of the head.
	tube(bm, [(bottom, 0.0078), (bottom + 0.004, 0.0098), (bottom + 0.024, 0.0094)], 10, 1)
	tube(bm, [(top - 0.004, 0.0094), (top + 0.012, 0.0088)], 10, 1)
	# Red lacquered bindings below the head.
	for z in (top - 0.05, top - 0.068):
		tube(bm, [(z, 0.0099), (z + 0.007, 0.0099)], 10, 2)
	# The spearhead.
	blade(bm, [(top + 0.012, 0.0062, 0.0042), (top + 0.026, 0.0108, 0.0036), (top + 0.04, 0.0112, 0.003),
			(top + 0.062, 0.0078, 0.0022), (top + 0.08, 0.0035, 0.0012), (top + 0.09, 0.0, 0.0)], 1)
	# The dagger-axe blade, forward (+y), with its tang behind and the curved
	# edge (hu) running down the shaft.
	z0 = top - 0.012
	outline = [(-0.024, 0.006), (-0.024, -0.003), (-0.006, -0.003), (0.004, -0.006), (0.006, -0.036),
			(0.013, -0.04), (0.016, -0.014), (0.032, -0.015), (0.056, -0.019), (0.08, -0.024),
			(0.062, -0.006), (0.036, 0.003), (0.012, 0.007), (-0.006, 0.007)]
	plate(bm, [(y, z0 + z) for y, z in outline], 0.0016, 1)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	ob = bpy.data.objects.new("Ji", mesh)
	scene.collection.objects.link(ob)
	return ob


def hand_frame(side):
	"""Where the fist closes, in the hand bone's space."""
	return Vector((0.003, 0.062, -0.006)) if side == "R" else Vector((-0.002, 0.056, -0.003))


def attach_to_hand(ob, side):
	"""Parents `ob` to the hand bone; its local frame = the bone's frame at the grip."""
	bone = bones[side + "_Hand"]
	ob.parent = arm
	ob.parent_type = 'BONE'
	ob.parent_bone = bone.name
	bpy.context.view_layer.update()
	ob.matrix_world = arm.matrix_world @ bone.matrix_local @ Matrix.Translation(hand_frame(side))


# Attach in the rest pose: the import leaves the first frame of a clip posed.
for pb in pose:
	pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()


ji = build_ji()
attach_to_hand(ji, "R")
grip = bpy.data.objects.new("TorchGrip", None)
scene.collection.objects.link(grip)
attach_to_hand(grip, "L")

# --- Posing helpers --------------------------------------------------------------------

def update():
	bpy.context.view_layer.update()


def set_world_rotation(pb, rot3, at=None):
	"""Poses `pb` (armature space) to orientation rot3, keeping its head."""
	head = pb.matrix.translation.copy() if at is None else at
	m = rot3.to_4x4()
	m.translation = head
	pb.matrix = m
	update()


def swing(pb, direction):
	"""Turns `pb` the least amount so its Y axis points along `direction`."""
	cur = pb.matrix.to_3x3()
	q = cur.col[1].normalized().rotation_difference(direction.normalized())
	set_world_rotation(pb, q.to_matrix() @ cur)


def chest_delta():
	return pose["Spine02"].matrix @ CHEST_REST.inverted()


def solve_arm(side, wrist_rest, pole_rest, hand_rot_rest, follow=True):
	"""Two-bone IK: wrist to a point given in the rest frame (following the
	chest, unless `follow` is off: then the point stays put in the model)."""
	d = chest_delta() if follow else Matrix.Identity(4)
	wrist = d @ wrist_rest
	pole = d @ pole_rest
	upper = pose[side + "_Upperarm"]
	fore = pose[side + "_Forearm"]
	hand = pose[side + "_Hand"]
	for n in ("UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"):
		pose[side + "_" + n].matrix_basis = Matrix.Identity(4)
	update()
	s = upper.matrix.translation.copy()
	a, b = SHOULDER_LEN[side], FOREARM_LEN[side]
	to = wrist - s
	dist = min(to.length, (a + b) * 0.999)
	to_n = to.normalized()
	# Elbow: in the plane of shoulder, wrist and pole.
	cos_a = (a * a + dist * dist - b * b) / (2 * a * dist)
	cos_a = max(-1.0, min(1.0, cos_a))
	along = to_n * (a * cos_a)
	side_dir = (pole - s) - to_n * (pole - s).dot(to_n)
	side_dir = side_dir.normalized() if side_dir.length > 1e-6 else Vector((0, 0, -1))
	elbow = s + along + side_dir * (a * math.sqrt(max(0.0, 1 - cos_a * cos_a)))
	swing(upper, elbow - s)
	swing(fore, (s + to_n * dist) - elbow)
	rot = d.to_3x3() @ hand_rot_rest
	set_world_rotation(hand, rot)


def key_arms(frame, sides):
	for side in sides:
		for n in ("Upperarm", "Forearm", "Hand", "UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"):
			pb = pose[side + "_" + n]
			pb.rotation_mode = 'QUATERNION'
			pb.keyframe_insert("rotation_quaternion", frame=frame)
			pb.keyframe_insert("location", frame=frame)


def rot_from(x, y, z):
	return Matrix((x, y, z)).transposed()


def rot_world(axis, deg):
	return Matrix.Rotation(math.radians(deg), 3, axis)


# Hand orientations in the rest frame (columns: the hand bone's x = back of
# the hand, y = fingers, z = across the palm, where the shaft lies): fingers
# forward, the ji upright; tilted forward for the other stances.
HOLD = rot_from(Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))
TORCH_ROT = rot_from(Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))

STANCES = {
	# wrist (rest frame), pole, hand rotation
	"hold": (Vector((0.07, -0.165, 0.535)), Vector((-0.2, -0.3, 0.55)), HOLD),
	"run": (Vector((0.11, -0.12, 0.6)), Vector((-0.15, -0.35, 0.5)), rot_world('Y', 40) @ HOLD),
}
TORCH_HAND = (Vector((0.13, 0.135, 0.66)), Vector((-0.1, 0.35, 0.45)), TORCH_ROT)


def shaft_dir(pitch, yaw):
	p, y = math.radians(pitch), math.radians(yaw)
	return Vector((math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), math.sin(p)))


def overhand(s):
	"""Right hand from above on a levelled shaft: back of the hand out and down."""
	x = Vector((0, -1, -0.35))
	x = (x - s * s.dot(x)).normalized()
	return rot_from(x, s.cross(x).normalized(), s)


def underhand(s):
	"""Left hand under the shaft, palm up."""
	x = Vector((0, 0, 1))
	x = (x - s * s.dot(x)).normalized()
	return rot_from(x, s.cross(x).normalized(), s)


# The levelled stance: rear (right) fist at the hip, the front (left) fist
# further along the shaft; in a thrust the right hand drives the shaft
# forward through the left.
LEVEL = shaft_dir(-2.0, 12.0)
REAR_FIST = Vector((0.005, -0.085, 0.57))
FRONT_ON_SHAFT = 0.19


def levelled(push, torch):
	rot_r = overhand(LEVEL)
	fist_r = REAR_FIST + LEVEL * push
	right = (fist_r - rot_r @ hand_frame("R"), Vector((-0.25, -0.35, 0.4)), rot_r)
	if torch:
		return right, TORCH_HAND
	rot_l = underhand(LEVEL)
	fist_l = REAR_FIST + LEVEL * FRONT_ON_SHAFT
	left = (fist_l - rot_l @ hand_frame("L"), Vector((0.05, 0.4, 0.3)), rot_l)
	return right, left

# --- Actions ----------------------------------------------------------------------------

def frames_of(action):
	a, b = action.frame_range
	return int(round(a)), int(round(b))


def make_from(base_name, new_name, stance, torch):
	src = bpy.data.actions[BASE[base_name]]
	act = src.copy()
	act.name = new_name
	arm.animation_data.action = act
	f0, f1 = frames_of(act)
	for f in range(f0, f1 + 1):
		scene.frame_set(f)
		if stance == "levelled":
			right, left = levelled(0.0, torch)
			solve_arm("R", *right)
			solve_arm("L", *left)
			sides = ["R", "L"]
		else:
			wrist, pole, rot = STANCES[stance]
			solve_arm("R", wrist, pole, rot)
			sides = ["R"]
			if torch:
				solve_arm("L", *TORCH_HAND)
				sides.append("L")
		key_arms(f, sides)
	act.use_fake_user = True
	return act


def stance_action(name, torch, keys, length):
	"""A new action on the idle's first frame: keys = {frame: (lean_deg, twist_deg, push, lunge)}."""
	act = bpy.data.actions.new(name)
	arm.animation_data.action = bpy.data.actions[BASE["idle"]]
	scene.frame_set(0)
	base = {pb.name: pb.matrix_basis.copy() for pb in pose}
	arm.animation_data.action = act
	for frame, (lean, twist, offset, lunge) in sorted(keys.items()):
		for pb in pose:
			pb.matrix_basis = base[pb.name]
		update()
		# The whole body drives forward into the thrust (and dips a little).
		hip = pose["Hip"]
		m = hip.matrix.copy()
		m.translation = m.translation + Vector((lunge, 0.0, -lunge * 0.35))
		hip.matrix = m
		update()
		# Lean forward and turn the shoulders (about the body's own axes).
		for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
			pb = pose[bn]
			r = rot_world('Z', twist * share) @ rot_world('Y', lean * share)
			set_world_rotation(pb, r @ pb.matrix.to_3x3())
		for bn in ("Head",):
			pb = pose[bn]
			set_world_rotation(pb, rot_world('Y', -lean * 0.7) @ rot_world('Z', -twist * 0.6) @ pb.matrix.to_3x3())
		right, left = levelled(offset, torch)
		solve_arm("R", *right, follow=False)
		solve_arm("L", *left, follow=not torch)
		for pb in pose:
			pb.rotation_mode = 'QUATERNION'
			pb.keyframe_insert("rotation_quaternion", frame=frame)
			pb.keyframe_insert("location", frame=frame)
	act.use_fake_user = True
	return act


made = []
for torch in (False, True):
	prefix = "torch_" if torch else ""
	made.append(make_from("idle", prefix + "idle", "hold", torch))
	made.append(make_from("idle_alt", prefix + "idle_alt", "hold", torch))
	made.append(make_from("walk", prefix + "walk", "hold", torch))
	made.append(make_from("walk", prefix + "advance", "levelled", torch))
	made.append(make_from("run", prefix + "run", "run", torch))
	made.append(make_from("talk", prefix + "talk", "hold", torch))
	# Ready: halberd levelled, breathing.
	made.append(stance_action(prefix + "ready", torch, {
		0: (9.0, 0.0, 0.0, 0.0),
		24: (10.5, 1.5, 0.004, 0.003),
		48: (9.0, 0.0, 0.0, 0.0),
	}, 48))
	# Attack: draw back, thrust (lands at frame 11 = 0.45 s), hold, recover.
	made.append(stance_action(prefix + "attack", torch, {
		0: (9.0, 0.0, 0.0, 0.0),
		7: (4.0, -16.0, -0.07, -0.02),
		11: (22.0, 18.0, 0.18, 0.05),
		15: (20.0, 15.0, 0.17, 0.045),
		24: (9.0, 0.0, 0.0, 0.0),
	}, 24))

for act in list(bpy.data.actions):
	if act not in made:
		bpy.data.actions.remove(act)
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(0)

os.makedirs(os.path.dirname(DST), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
		export_force_sampling=True, export_yup=True, export_apply=False)
print("built", DST, "with", sorted(a.name for a in bpy.data.actions))
