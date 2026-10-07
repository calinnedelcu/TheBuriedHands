class_name Masonry
extends RefCounted
## Dressed stone and timber for the level kit, laid the way the workshop is
## built: courses of blocks with bevelled edges and dark joints on walls, big
## flagstones on floors, boards under timber ceilings. Every piece is the same
## bevelled box in a MultiMesh, scaled to its size and tinted a shade lighter
## or darker than its neighbours; the plain face behind shows dark in the
## joints. Only for looks: the kit keeps its plain box colliders.

const TINTED_SHADER := preload("res://assets/shaders/surface_triplanar_tinted.gdshader")

static var _box: ArrayMesh = null
static var _tinted := {}
static var _joints := {}

## A unit box (-0.5..0.5 on every axis) with its edges chamfered.
static func box() -> ArrayMesh:
	if _box != null:
		return _box
	var h := 0.5
	var i := h - 0.09
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The six faces, inset from the edges.
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var pts: Array[Vector3] = []
			for corner in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var p := Vector3.ZERO
				p[axis] = sgn * h
				p[(axis + 1) % 3] = corner[0] * i
				p[(axis + 2) % 3] = corner[1] * i
				pts.append(p)
			_poly(st, pts, n)
	# The twelve chamfers along the edges.
	for a in 3:
		for b in range(a + 1, 3):
			var o := 3 - a - b
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var n := Vector3.ZERO
					n[a] = sa
					n[b] = sb
					var pts: Array[Vector3] = []
					for so in [-1.0, 1.0]:
						var on_a := Vector3.ZERO
						on_a[a] = sa * h
						on_a[b] = sb * i
						on_a[o] = so * i
						var on_b := Vector3.ZERO
						on_b[a] = sa * i
						on_b[b] = sb * h
						on_b[o] = so * i
						pts.append(on_a)
						pts.append(on_b)
					_poly(st, [pts[0], pts[1], pts[3], pts[2]], n.normalized())
	# The eight corners.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_poly(st, [Vector3(sx * h, sy * i, sz * i), Vector3(sx * i, sy * h, sz * i), Vector3(sx * i, sy * i, sz * h)], Vector3(sx, sy, sz).normalized())
	_box = st.commit()
	return _box

## A convex polygon facing `n`, its points in order round it; wound for
## Godot's clockwise front faces.
static func _poly(st: SurfaceTool, pts: Array, n: Vector3) -> void:
	for k in range(1, pts.size() - 1):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[k]
		var c: Vector3 = pts[k + 1]
		if (b - a).cross(c - a).dot(n) > 0.0:
			var t := b
			b = c
			c = t
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)

## `mat` drawn with each piece's own tint (one copy per material).
static func tinted(mat: Material) -> Material:
	if mat == null or _tinted.has(mat):
		return _tinted.get(mat, null)
	var out: Material = mat
	if mat is ShaderMaterial:
		var src := mat as ShaderMaterial
		var m := ShaderMaterial.new()
		m.shader = TINTED_SHADER
		for u in src.shader.get_shader_uniform_list():
			m.set_shader_parameter(u.name, src.get_shader_parameter(u.name))
		out = m
	elif mat is BaseMaterial3D:
		var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.vertex_color_use_as_albedo = true
		out = m
	_tinted[mat] = out
	return out

## `mat` much darker: the mortar and shadow in the joints between pieces.
static func joints(mat: Material) -> Material:
	if mat == null or _joints.has(mat):
		return _joints.get(mat, null)
	var out: Material = mat
	if mat is ShaderMaterial:
		var m := (mat as ShaderMaterial).duplicate() as ShaderMaterial
		var c: Variant = m.get_shader_parameter(&"base_color")
		if c is Color:
			m.set_shader_parameter(&"base_color", (c as Color).darkened(0.45))
		out = m
	elif mat is BaseMaterial3D:
		var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.albedo_color = m.albedo_color.darkened(0.45)
		out = m
	_joints[mat] = out
	return out

## Whether a material is wood (its ceilings get boards, not slabs).
static func is_timber(mat: Material) -> bool:
	if mat == null:
		return false
	var p := mat.resource_path.to_lower()
	return p.contains("timber") or p.contains("wood") or p.contains("roof")

## Where the courses meet, from 0 up to `h`: about `course` apart, no two
## quite alike. One set per room or block, so the courses run on round its
## corners.
static func course_lines(rng: RandomNumberGenerator, h: float, course: float) -> PackedFloat32Array:
	var rows := maxi(1, roundi(h / course))
	var heights: Array[float] = []
	var total := 0.0
	for r in rows:
		heights.append(rng.randf_range(0.82, 1.18))
		total += heights[r]
	var out := PackedFloat32Array([0.0])
	var v := 0.0
	for r in rows:
		v += heights[r] / total * h
		out.append(v)
	out[rows] = h
	return out

## Courses of blocks over the band v0..v1 of a wall w long (u along, v up),
## on the course `lines`, in a running bond: [u, v, length, height] of each
## block's lower corner and size. A course cut very thin at the band's edge
## joins the one next to it.
static func courses(rng: RandomNumberGenerator, w: float, v0: float, v1: float, lines: PackedFloat32Array, lengths: Vector2) -> Array:
	var cuts: Array[float] = [v0]
	for line in lines:
		if line > v0 + 0.001 and line < v1 - 0.001:
			cuts.append(line)
	cuts.append(v1)
	var k := 1
	while k < cuts.size() - 1:
		if cuts[k] - cuts[k - 1] < 0.2 or cuts[k + 1] - cuts[k] < 0.2:
			cuts.remove_at(k)
		else:
			k += 1
	var out := []
	for r in cuts.size() - 1:
		var v := cuts[r]
		var ch := cuts[r + 1] - v
		var u := 0.0
		# Every other course starts a part-block in, so joints don't line up.
		var l := rng.randf_range(0.35, 0.7) * lengths.y if roundi(v * 7.0) % 2 == 1 else rng.randf_range(lengths.x, lengths.y)
		while u < w - 0.001:
			l = minf(l, w - u)
			# No sliver at the end of a course: this block runs to the edge.
			if w - (u + l) < lengths.x * 0.45:
				l = w - u
			out.append([u, v, l, ch])
			u += l
			l = rng.randf_range(lengths.x, lengths.y)
	return out

## Rows of slabs over a w × d rectangle (rows across d, slabs along w):
## flagstones on a floor, boards under a ceiling. [u, v, length, width].
static func rows(rng: RandomNumberGenerator, w: float, d: float, widths: Vector2, lengths: Vector2) -> Array:
	var out := []
	var v := 0.0
	while v < d - 0.001:
		var rw := minf(rng.randf_range(widths.x, widths.y), d - v)
		if d - (v + rw) < widths.x * 0.5:
			rw = d - v
		var u := 0.0
		var l := rng.randf_range(0.35, 1.0) * lengths.y
		while u < w - 0.001:
			l = minf(l, w - u)
			if w - (u + l) < lengths.x * 0.45:
				l = w - u
			out.append([u, v, l, rw])
			u += l
			l = rng.randf_range(lengths.x, lengths.y)
		v += rw
	return out

## A piece `size` (along a, along b, along c) centred on `centre`, a little
## turned about c and, by `wobble`, about a and b (hand-cut, hand-set);
## a, b, c are unit axes of either handedness.
static func piece(centre: Vector3, a: Vector3, b: Vector3, c: Vector3, size: Vector3, twist := 0.0, wobble := Vector2.ZERO) -> Transform3D:
	var basis := Basis(a * size.x, b * size.y, c * size.z)
	if basis.determinant() < 0.0:
		basis = Basis(a * size.x, b * size.y, -c * size.z)
	if twist != 0.0:
		basis = Basis(c.normalized(), twist) * basis
	if wobble != Vector2.ZERO:
		basis = Basis(a.normalized(), wobble.x) * Basis(b.normalized(), wobble.y) * basis
	return Transform3D(basis, centre)

## A small random wobble for `piece`.
static func wobble(rng: RandomNumberGenerator, degrees: float) -> Vector2:
	return Vector2(deg_to_rad(rng.randf_range(-degrees, degrees)), deg_to_rad(rng.randf_range(-degrees, degrees)))

## Pieces gathered by material, then built as one MultiMesh each.
class Batch:
	var _parts := {}

	func add(mat: Material, xf: Transform3D, shade: float) -> void:
		if not _parts.has(mat):
			_parts[mat] = [[], PackedColorArray()]
		_parts[mat][0].append(xf)
		_parts[mat][1].append(Color(shade, shade, shade))

	func is_empty() -> bool:
		return _parts.is_empty()

	## Adds the multimeshes under `parent`, marked as generated.
	func build(parent: Node3D) -> void:
		for mat in _parts:
			var xfs: Array = _parts[mat][0]
			var colors: PackedColorArray = _parts[mat][1]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = Masonry.box()
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, xfs[k])
				mm.set_instance_color(k, colors[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Masonry"
			mmi.multimesh = mm
			mmi.material_override = Masonry.tinted(mat)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta(&"generated", true)
			parent.add_child(mmi)
