# Low-to-the-ground clips for the player characters, as the other co-op
# player sees them: crouching (still and walking) and crawling on hands and
# knees (still and moving), plus a plain standing idle for a model that has
# none. Built on the rest pose with the leg and arm IK of rig_tools; each
# walking cycle is timed so the feet don't slide at the player's speed.
#
#   clips = Locomotion(rig, model_scale, crouch_speed, crawl_speed).build(idle=True)

import bpy, math
from mathutils import Vector, Matrix
from rig_tools import rot_from, rot_world

FPS = 24


def frame_y(y, x_hint):
	"""A hand orientation: fingers (y) along `y`, its x toward x_hint (the back
	of the right hand, the palm of the left)."""
	y = y.normalized()
	x = (x_hint - y * y.dot(x_hint)).normalized()
	return rot_from(x, y, x.cross(y))


# Fingers forward and a little down; the right hand's back up, the left's palm down.
HAND_R = frame_y(Vector((1.0, 0.05, -0.35)), Vector((0, 0, 1)))
HAND_L = frame_y(Vector((1.0, -0.05, -0.35)), Vector((0, 0, -1)))
# Flat on the floor, fingers ahead.
PALM_R = frame_y(Vector((1.0, -0.15, -0.05)), Vector((0, 0, 1)))
PALM_L = frame_y(Vector((1.0, 0.15, -0.05)), Vector((0, 0, -1)))
FOOT_FLAT = Vector((1.0, 0.0, -0.09))
FOOT_BACK = Vector((-1.0, 0.0, 0.12))


class Locomotion:
	def __init__(self, rig, model_scale, crouch_speed, crawl_speed):
		self.rig = rig
		self.scale = model_scale
		self.crouch_speed = crouch_speed
		self.crawl_speed = crawl_speed
		b = rig.bones
		self.hip_z = b["Hip"].head_local.z
		self.ankle = {s: b[s + "_Foot"].head_local.copy() for s in "LR"}
		self.thigh = rig.thigh_len["L"]
		self.leg = rig.thigh_len["L"] + rig.calf_len["L"]

	def _frames(self, travel, speed):
		"""Frames in a cycle that carries the body `travel` model units at the
		game's `speed` (game units a second)."""
		return max(12, int(round(FPS * travel / (speed / self.scale))))

	def _new(self, name):
		act = bpy.data.actions.new(name)
		act.use_fake_user = True
		self.rig.arm.animation_data.action = act
		return act

	def _rest(self):
		self.rig.rest_pose()

	def _body(self, drop, back, tilt, lean, head, twist=0.0):
		r = self.rig
		self._rest()
		r.place_hip(Vector((-back, 0.0, -drop)), rot_world('Y', tilt))
		for bn, share in (("Spine01", 0.45), ("Spine02", 0.55)):
			r.turn(bn, rot_world('Z', twist * share) @ rot_world('Y', lean * share))
		r.turn("Head", rot_world('Z', -twist * 0.8) @ rot_world('Y', head))

	def _shoulder(self, side):
		return self.rig.pose[side + "_Upperarm"].matrix.translation.copy()

	# --- Standing -----------------------------------------------------------------------

	def idle(self):
		act = self._new("idle")
		for f, breath in ((0, 0.0), (36, 1.0), (72, 0.0)):
			self._body(0.0, 0.0, 0.0, 1.5 + breath * 1.2, -1.5 - breath)
			for side, sy, pole_y, rot in (("L", 1, 0.5, frame_y(Vector((0.1, 0.1, -1.0)), Vector((0, -1, 0)))),
					("R", -1, -0.5, frame_y(Vector((0.1, -0.1, -1.0)), Vector((0, -1, 0))))):
				sh = self._shoulder(side)
				fist = sh + Vector((0.03, sy * 0.05, -0.29 + breath * 0.004))
				self.rig.solve_arm(side, fist, sh + Vector((-0.35, pole_y, -0.1)), rot, follow=False)
			self.rig.key_all(f)
		return act

	# --- Crouching ----------------------------------------------------------------------

	CROUCH_DROP = 0.15
	CROUCH_STEP = 0.24

	def _crouch_pose(self, phase=None, breath=0.0):
		"""phase None: still; else 0..1 through the walking cycle."""
		bob = 0.0 if phase is None else -0.008 * math.cos(4 * math.pi * phase)
		twist = 0.0 if phase is None else 4.0 * math.sin(2 * math.pi * phase)
		self._body(self.CROUCH_DROP + bob, 0.03, 18.0, 14.0 + breath, -26.0 - breath, twist)
		feet = {}
		for side, offset in (("L", 0.0), ("R", 0.5)):
			a = self.ankle[side].copy()
			lift = 0.0
			if phase is None:
				a.x += 0.04 if side == "L" else -0.05
			else:
				p = (phase + offset) % 1.0
				if p < 0.5:
					a.x += self.CROUCH_STEP * (0.5 - p / 0.5)
				else:
					q = (p - 0.5) / 0.5
					a.x += self.CROUCH_STEP * (q - 0.5)
					lift = 0.05 * math.sin(math.pi * q)
			a.z += lift
			pole = Vector((a.x + 0.5, a.y * 1.6, 0.3))
			self.rig.solve_leg(side, a, pole, FOOT_FLAT if lift < 0.02 else Vector((1.0, 0.0, -0.35)))
		for side, sy, rot in (("L", 1, HAND_L), ("R", -1, HAND_R)):
			swing = 0.0 if phase is None else 0.035 * math.sin(2 * math.pi * phase + (math.pi if side == "L" else 0.0))
			fist = Vector((0.2 + swing, sy * 0.14, 0.3 + breath * 0.002))
			self.rig.solve_arm(side, fist, Vector((-0.1, sy * 0.5, 0.45)), rot, follow=False)

	def crouch_idle(self):
		act = self._new("crouch_idle")
		for f, breath in ((0, 0.0), (30, 1.0), (60, 0.0)):
			self._crouch_pose(None, breath)
			self.rig.key_all(f)
		return act

	def crouch_walk(self):
		act = self._new("crouch_walk")
		frames = self._frames(self.CROUCH_STEP * 2.0, self.crouch_speed)
		for k in range(9):
			self._crouch_pose(k / 8.0)
			self.rig.key_all(round(frames * k / 8.0))
		return act

	# --- Crawling, on hands and knees -------------------------------------------------------

	CRAWL_STEP = 0.12

	def _crawl_pose(self, phase=None, breath=0.0):
		knee_z = 0.035
		drop = self.hip_z - (knee_z + self.thigh * 0.97)
		self._body(drop, 0.06, 78.0, -6.0 + breath, -62.0)
		for side, offset in (("L", 0.0), ("R", 0.5)):
			slide = 0.0
			lift = 0.0
			if phase is not None:
				p = (phase + offset) % 1.0
				if p < 0.5:
					slide = self.CRAWL_STEP * (0.5 - p / 0.5)
				else:
					q = (p - 0.5) / 0.5
					slide = self.CRAWL_STEP * (q - 0.5)
					lift = 0.025 * math.sin(math.pi * q)
			hip = self.rig.pose[side + "_Thigh"].matrix.translation
			ankle = Vector((hip.x - 0.23 + slide, self.ankle[side].y * 1.05, 0.045 + lift))
			pole = Vector((hip.x + 0.4, self.ankle[side].y, -0.6))
			self.rig.solve_leg(side, ankle, pole, FOOT_BACK)
		for side, sy, rot, offset in (("L", 1, PALM_L, 0.5), ("R", -1, PALM_R, 0.0)):
			sh = self._shoulder(side)
			slide = 0.0
			lift = 0.0
			if phase is not None:
				p = (phase + offset) % 1.0
				if p < 0.5:
					slide = self.CRAWL_STEP * (0.5 - p / 0.5)
				else:
					q = (p - 0.5) / 0.5
					slide = self.CRAWL_STEP * (q - 0.5)
					lift = 0.03 * math.sin(math.pi * q)
			fist = Vector((sh.x + 0.03 + slide, sy * 0.13, 0.04 + lift))
			self.rig.solve_arm(side, fist, Vector((sh.x - 0.3, sy * 0.45, 0.35)), rot, follow=False)

	def crawl_idle(self):
		act = self._new("crawl_idle")
		for f, breath in ((0, 0.0), (30, 1.0), (60, 0.0)):
			self._crawl_pose(None, breath)
			self.rig.key_all(f)
		return act

	def crawl(self):
		act = self._new("crawl")
		frames = self._frames(self.CRAWL_STEP * 2.0, self.crawl_speed)
		for k in range(9):
			self._crawl_pose(k / 8.0)
			self.rig.key_all(round(frames * k / 8.0))
		return act

	def build(self, idle=False):
		made = [self.crouch_idle(), self.crouch_walk(), self.crawl_idle(), self.crawl()]
		if idle:
			made.append(self.idle())
		self._rest()
		return made
