# Shared helpers for posing the jam's Tripo-rigged characters in Blender
# (41-bone rigs: Root, Hip, Spine01/02, *_Upperarm, *_Forearm, *_Hand, ...).
#
# Targets are given in the model's rest frame (x forward, y left, z up,
# model units) and, by default, follow the chest as the base clip moves it.

import bpy, math
from mathutils import Vector, Matrix


class Rig:
	def __init__(self, glb_path):
		bpy.ops.wm.read_factory_settings(use_empty=True)
		bpy.ops.import_scene.gltf(filepath=glb_path)
		self.scene = bpy.context.scene
		self.scene.render.fps = 24
		for ob in list(bpy.data.objects):
			if ob.name.startswith("Icosphere"):
				bpy.data.objects.remove(ob, do_unlink=True)
		self.arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
		self.body = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == self.arm][0]
		self.bones = self.arm.data.bones
		self.pose = self.arm.pose.bones
		bpy.context.view_layer.objects.active = self.arm
		self.arm.animation_data.action = None
		for t in list(self.arm.animation_data.nla_tracks):
			self.arm.animation_data.nla_tracks.remove(t)
		self.rest_pose()
		self.upper_len = {s: (self._head(s + "_Forearm") - self._head(s + "_Upperarm")).length for s in "RL"}
		self.fore_len = {s: (self._head(s + "_Hand") - self._head(s + "_Forearm")).length for s in "RL"}
		self.chest_rest = self.bones["Spine02"].matrix_local.copy()
		self.grip = {s: self._fist(s) for s in "RL"}

	def _head(self, name):
		return self.bones[name].head_local.copy()

	def _fist(self, side):
		"""Centre of the hand's vertices, in the hand bone's space."""
		bone = self.bones[side + "_Hand"]
		inv = bone.matrix_local.inverted()
		gi = self.body.vertex_groups[side + "_Hand"].index
		pts = []
		for v in self.body.data.vertices:
			for g in v.groups:
				if g.group == gi and g.weight > 0.5:
					pts.append(inv @ (self.body.matrix_world @ v.co))
		c = sum(pts, Vector()) / max(1, len(pts))
		return Vector((c.x * 0.3, c.y, c.z * 0.5))

	def update(self):
		bpy.context.view_layer.update()

	def rest_pose(self):
		for pb in self.arm.pose.bones:
			pb.matrix_basis = Matrix.Identity(4)
		self.update()

	# --- Attachments ---------------------------------------------------------------------

	def attach(self, ob, side):
		"""Parents `ob` to the hand bone, its frame = the bone's frame at the fist (rest pose)."""
		bone = self.bones[side + "_Hand"]
		ob.parent = self.arm
		ob.parent_type = 'BONE'
		ob.parent_bone = bone.name
		self.update()
		ob.matrix_world = self.arm.matrix_world @ bone.matrix_local @ Matrix.Translation(self.grip[side])

	# --- Posing ---------------------------------------------------------------------------

	def set_rotation(self, pb, rot3, at=None):
		head = pb.matrix.translation.copy() if at is None else at
		m = rot3.to_4x4()
		m.translation = head
		pb.matrix = m
		self.update()

	def swing(self, pb, direction):
		cur = pb.matrix.to_3x3()
		q = cur.col[1].normalized().rotation_difference(direction.normalized())
		self.set_rotation(pb, q.to_matrix() @ cur)

	def turn(self, bone_name, rot3):
		"""Rotates a bone (and what hangs from it) by rot3, about its head, in model space."""
		pb = self.pose[bone_name]
		self.set_rotation(pb, rot3 @ pb.matrix.to_3x3())

	def chest_delta(self):
		return self.pose["Spine02"].matrix @ self.chest_rest.inverted()

	def solve_arm(self, side, fist, pole, hand_rot, follow=True):
		"""Two-bone IK putting the fist at `fist` with the hand turned to hand_rot."""
		d = self.chest_delta() if follow else Matrix.Identity(4)
		rot = d.to_3x3() @ hand_rot
		wrist = d @ fist - rot @ self.grip[side]
		pole_w = d @ pole
		upper = self.pose[side + "_Upperarm"]
		fore = self.pose[side + "_Forearm"]
		hand = self.pose[side + "_Hand"]
		for n in ("UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02"):
			self.pose[side + "_" + n].matrix_basis = Matrix.Identity(4)
		self.update()
		s = upper.matrix.translation.copy()
		a, b = self.upper_len[side], self.fore_len[side]
		to = wrist - s
		dist = min(to.length, (a + b) * 0.999)
		to_n = to.normalized()
		cos_a = max(-1.0, min(1.0, (a * a + dist * dist - b * b) / (2 * a * dist)))
		side_dir = (pole_w - s) - to_n * (pole_w - s).dot(to_n)
		side_dir = side_dir.normalized() if side_dir.length > 1e-6 else Vector((0, 0, -1))
		elbow = s + to_n * (a * cos_a) + side_dir * (a * math.sqrt(max(0.0, 1 - cos_a * cos_a)))
		self.swing(upper, elbow - s)
		self.swing(fore, (s + to_n * dist) - elbow)
		self.set_rotation(hand, rot)

	def key(self, frame, bone_names):
		for n in bone_names:
			pb = self.pose[n]
			pb.rotation_mode = 'QUATERNION'
			pb.keyframe_insert("rotation_quaternion", frame=frame)
			pb.keyframe_insert("location", frame=frame)

	def key_all(self, frame):
		self.key(frame, [pb.name for pb in self.pose])

	def arm_bones(self, side):
		return [side + "_" + n for n in ("Upperarm", "Forearm", "Hand", "UpperarmTwist01", "UpperarmTwist02", "ForearmTwist01", "ForearmTwist02")]

	def frames(self, action):
		a, b = action.frame_range
		return int(round(a)), int(round(b))

	def export(self, path, keep):
		for act in list(bpy.data.actions):
			if act not in keep:
				bpy.data.actions.remove(act)
		self.arm.animation_data.action = keep[0]
		self.scene.frame_set(0)
		bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
				export_force_sampling=True, export_yup=True, export_apply=False)


def rot_from(x, y, z):
	return Matrix((x, y, z)).transposed()


def rot_world(axis, deg):
	return Matrix.Rotation(math.radians(deg), 3, axis)


def material(name, color, metallic, roughness):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return m
