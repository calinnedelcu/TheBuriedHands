@tool
class_name ToolVisuals
extends RefCounted

const SLOT_CHISEL := 1
const SLOT_WEDGE := 2
const SLOT_CERAMIC := 3
const SLOT_HAMMER := 4
const SLOT_WAX_TABLET := 5
const SLOT_VAPOR_MASK := 6

const SLOT_NAMES := {
	SLOT_CHISEL: "Daltă",
	SLOT_WEDGE: "Pană de lemn",
	SLOT_CERAMIC: "Cioburi de ceramică",
	SLOT_HAMMER: "Ciocan de lemn",
	SLOT_WAX_TABLET: "Tăbliță de ceară",
	SLOT_VAPOR_MASK: "Masca de panza",
}

const SLOT_BY_ITEM_ID := {
	"chisel": SLOT_CHISEL,
	"wedge": SLOT_WEDGE,
	"ceramic": SLOT_CERAMIC,
	"hammer": SLOT_HAMMER,
	"wax_tablet": SLOT_WAX_TABLET,
	"vapor_mask": SLOT_VAPOR_MASK,
}

static func slot_name(slot: int) -> String:
	return SLOT_NAMES.get(slot, "Unealtă")

static func slot_for_item_id(item_id: String) -> int:
	return SLOT_BY_ITEM_ID.get(item_id, -1)

static func item_display_name(item_id: String) -> String:
	return slot_name(slot_for_item_id(item_id))

static func build_for_item_id(item_id: String, in_hand: bool) -> Node3D:
	if item_id == "vapor_mask":
		var root := Node3D.new()
		root.name = "VaporMaskVisual"
		_build_vapor_mask(root, 1.0 if in_hand else 1.55, in_hand)
		_apply_pose(root, SLOT_VAPOR_MASK, in_hand)
		return root
	return build_for_slot(slot_for_item_id(item_id), in_hand)

static func pickup_prompt(slot: int) -> String:
	match slot:
		SLOT_CHISEL:
			return "Ridică dalta"
		SLOT_WEDGE:
			return "Ridică pana de lemn"
		SLOT_CERAMIC:
			return "Ridică cioburile de ceramică"
		SLOT_HAMMER:
			return "Ridică ciocanul"
		SLOT_WAX_TABLET:
			return "Ridică tăblița de ceară"
	return "Ridică unealta"

static func pickup_prompt_for_item_id(item_id: String) -> String:
	if item_id == "vapor_mask":
		return "Ridica masca de panza"
	return pickup_prompt(slot_for_item_id(item_id))

static func glow_color_for_slot(slot: int) -> Color:
	match slot:
		SLOT_CHISEL:
			return Color(0.95, 0.82, 0.56, 1.0)
		SLOT_WEDGE:
			return Color(0.95, 0.62, 0.32, 1.0)
		SLOT_CERAMIC:
			return Color(0.95, 0.48, 0.26, 1.0)
		SLOT_HAMMER:
			return Color(1.0, 0.72, 0.36, 1.0)
		SLOT_WAX_TABLET:
			return Color(0.86, 0.7, 0.44, 1.0)
	return Color(1.0, 0.88, 0.55, 1.0)

static func glow_color_for_item_id(item_id: String) -> Color:
	if item_id == "vapor_mask":
		return Color(0.72, 0.86, 0.78, 1.0)
	return glow_color_for_slot(slot_for_item_id(item_id))

static func build_for_slot(slot: int, in_hand: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "%sVisual" % slot_name(slot).replace(" ", "")
	var scale_factor: float = 1.0 if in_hand else 1.55
	match slot:
		SLOT_CHISEL:
			_build_chisel(root, scale_factor, in_hand)
		SLOT_WEDGE:
			_build_wedge(root, scale_factor, in_hand)
		SLOT_CERAMIC:
			_build_ceramic(root, scale_factor, in_hand)
		SLOT_HAMMER:
			_build_hammer(root, scale_factor, in_hand)
		SLOT_WAX_TABLET:
			_build_wax_tablet(root, scale_factor, in_hand)
		_:
			return null
	_apply_pose(root, slot, in_hand)
	return root

static func _build_chisel(root: Node3D, s: float, in_hand: bool) -> void:
	var wood := _mat(Color(0.34, 0.21, 0.12, 1.0), 0.0, 0.88, in_hand)
	var dark_wood := _mat(Color(0.2, 0.12, 0.07, 1.0), 0.0, 0.9, in_hand)
	var bronze := _mat(Color(0.55, 0.47, 0.35, 1.0), 0.18, 0.62, in_hand)
	var edge := _mat(Color(0.78, 0.72, 0.62, 1.0), 0.35, 0.48, in_hand)
	_cylinder(root, "WoodGrip", 0.018 * s, 0.115 * s, Vector3(0.0, 0.0, 0.045) * s, Vector3(90, 0, 0), wood, 8)
	_cylinder(root, "GripBand", 0.0195 * s, 0.018 * s, Vector3(0.0, 0.0, -0.02) * s, Vector3(90, 0, 0), dark_wood, 8)
	_box(root, "BronzeBlade", Vector3(0.024, 0.018, 0.145) * s, Vector3(0.0, 0.0, -0.105) * s, Vector3.ZERO, bronze)
	_cylinder(root, "NarrowTip", 0.012 * s, 0.045 * s, Vector3(0.0, 0.0, -0.2) * s, Vector3(90, 0, 0), edge, 6, 0.004 * s)

static func _build_wedge(root: Node3D, s: float, in_hand: bool) -> void:
	var wood := _mat(Color(0.45, 0.27, 0.13, 1.0), 0.0, 0.9, in_hand)
	var end_grain := _mat(Color(0.58, 0.36, 0.18, 1.0), 0.0, 0.92, in_hand)
	var wedge := MeshInstance3D.new()
	wedge.name = "TaperedWedge"
	wedge.mesh = _make_wedge_mesh(Vector3(0.085, 0.045, 0.16) * s)
	wedge.material_override = wood
	root.add_child(wedge)
	_box(root, "StruckEnd", Vector3(0.09, 0.044, 0.018) * s, Vector3(0.0, 0.022 * s, -0.071 * s), Vector3.ZERO, end_grain)

static func _build_ceramic(root: Node3D, s: float, in_hand: bool) -> void:
	var clay := _mat(Color(0.61, 0.34, 0.2, 1.0), 0.0, 0.96, in_hand)
	var clay_light := _mat(Color(0.75, 0.47, 0.28, 1.0), 0.0, 0.95, in_hand)
	_box(root, "ShardA", Vector3(0.075, 0.014, 0.045) * s, Vector3(-0.028, 0.0, -0.015) * s, Vector3(4, 18, -12), clay)
	_box(root, "ShardB", Vector3(0.048, 0.012, 0.065) * s, Vector3(0.03, 0.004, -0.005) * s, Vector3(-8, -21, 9), clay_light)
	_box(root, "ShardC", Vector3(0.04, 0.011, 0.036) * s, Vector3(0.0, 0.014, -0.055) * s, Vector3(14, 4, 26), clay)

static func _build_hammer(root: Node3D, s: float, in_hand: bool) -> void:
	var wood := _mat(Color(0.37, 0.22, 0.11, 1.0), 0.0, 0.88, in_hand)
	var worn_wood := _mat(Color(0.52, 0.31, 0.15, 1.0), 0.0, 0.9, in_hand)
	var bronze := _mat(Color(0.48, 0.31, 0.16, 1.0), 0.28, 0.62, in_hand)
	_cylinder(root, "Handle", 0.018 * s, 0.26 * s, Vector3(0.0, -0.006, -0.015) * s, Vector3(90, 0, 0), wood, 8)
	_box(root, "GripWrapA", Vector3(0.045, 0.018, 0.018) * s, Vector3(0.0, -0.006, 0.08) * s, Vector3.ZERO, worn_wood)
	_box(root, "GripWrapB", Vector3(0.045, 0.018, 0.018) * s, Vector3(0.0, -0.006, 0.035) * s, Vector3.ZERO, worn_wood)
	_box(root, "HammerHead", Vector3(0.145, 0.07, 0.06) * s, Vector3(0.0, 0.0, -0.16) * s, Vector3.ZERO, bronze)
	_box(root, "HeadCapLeft", Vector3(0.022, 0.078, 0.068) * s, Vector3(-0.083, 0.0, -0.16) * s, Vector3.ZERO, bronze)
	_box(root, "HeadCapRight", Vector3(0.022, 0.078, 0.068) * s, Vector3(0.083, 0.0, -0.16) * s, Vector3.ZERO, bronze)

static func _build_wax_tablet(root: Node3D, s: float, in_hand: bool) -> void:
	var wood := _mat(Color(0.36, 0.22, 0.12, 1.0), 0.0, 0.88, in_hand)
	var wax := _mat(Color(0.62, 0.49, 0.32, 1.0), 0.0, 0.78, in_hand)
	_box(root, "WoodFrame", Vector3(0.16, 0.018, 0.1) * s, Vector3.ZERO, Vector3.ZERO, wood)
	_box(root, "WaxSurface", Vector3(0.12, 0.021, 0.066) * s, Vector3(0.0, 0.003 * s, 0.0), Vector3.ZERO, wax)
	_box(root, "IncisedLineA", Vector3(0.09, 0.004, 0.004) * s, Vector3(0.0, 0.017 * s, -0.016 * s), Vector3.ZERO, wood)
	_box(root, "IncisedLineB", Vector3(0.07, 0.004, 0.004) * s, Vector3(0.0, 0.017 * s, 0.011 * s), Vector3.ZERO, wood)

static func _build_vapor_mask(root: Node3D, s: float, in_hand: bool) -> void:
	var cloth := _mat(Color(0.55, 0.48, 0.36, 1.0), 0.0, 0.92, in_hand)
	var dark_cloth := _mat(Color(0.32, 0.27, 0.2, 1.0), 0.0, 0.95, in_hand)
	var cord := _mat(Color(0.2, 0.15, 0.1, 1.0), 0.0, 0.9, in_hand)
	_box(root, "FoldedCloth", Vector3(0.13, 0.028, 0.085) * s, Vector3.ZERO, Vector3.ZERO, cloth)
	_box(root, "FilterPad", Vector3(0.075, 0.034, 0.048) * s, Vector3(0.0, 0.004 * s, -0.006 * s), Vector3.ZERO, dark_cloth)
	_box(root, "FoldA", Vector3(0.118, 0.006, 0.006) * s, Vector3(0.0, 0.022 * s, -0.026 * s), Vector3.ZERO, dark_cloth)
	_box(root, "FoldB", Vector3(0.118, 0.006, 0.006) * s, Vector3(0.0, 0.022 * s, 0.024 * s), Vector3.ZERO, dark_cloth)
	_cylinder(root, "CordLeft", 0.004 * s, 0.11 * s, Vector3(-0.072, 0.0, 0.0) * s, Vector3(0, 0, 90), cord, 6)
	_cylinder(root, "CordRight", 0.004 * s, 0.11 * s, Vector3(0.072, 0.0, 0.0) * s, Vector3(0, 0, 90), cord, 6)

static func _apply_pose(root: Node3D, slot: int, in_hand: bool) -> void:
	if in_hand:
		root.position = Vector3(0.0, 0.0, -0.025)
		match slot:
			SLOT_CHISEL:
				root.rotation_degrees = Vector3(-8, -8, -5)
			SLOT_WEDGE:
				root.rotation_degrees = Vector3(-12, 10, 8)
			SLOT_CERAMIC:
				root.rotation_degrees = Vector3(-5, 18, -6)
			SLOT_HAMMER:
				root.position = Vector3(0.0, -0.005, -0.015)
				root.rotation_degrees = Vector3(-9, -12, 4)
			SLOT_WAX_TABLET:
				root.position = Vector3(0.0, 0.0, -0.04)
				root.rotation_degrees = Vector3(-18, 18, 0)
			SLOT_VAPOR_MASK:
				root.position = Vector3(0.0, -0.004, -0.035)
				root.rotation_degrees = Vector3(-14, 16, -4)
	else:
		root.position = Vector3(0.0, 0.075, 0.0)
		root.rotation_degrees = Vector3(0, 22, -6)

static func _box(root: Node3D, mesh_name: String, size: Vector3, position: Vector3, rot_deg: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.name = mesh_name
	mi.mesh = box
	mi.material_override = material
	mi.position = position
	mi.rotation_degrees = rot_deg
	root.add_child(mi)
	return mi

static func _cylinder(
	root: Node3D,
	mesh_name: String,
	radius: float,
	height: float,
	position: Vector3,
	rot_deg: Vector3,
	material: Material,
	segments: int = 8,
	top_radius: float = -1.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = radius
	cyl.top_radius = radius if top_radius < 0.0 else top_radius
	cyl.height = height
	cyl.radial_segments = segments
	mi.name = mesh_name
	mi.mesh = cyl
	mi.material_override = material
	mi.position = position
	mi.rotation_degrees = rot_deg
	root.add_child(mi)
	return mi

static func _mat(color: Color, metallic: float, roughness: float, in_hand: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if in_hand:
		mat.no_depth_test = true
		mat.render_priority = 8
	return mat

static func _make_wedge_mesh(size: Vector3) -> ArrayMesh:
	var hw := size.x * 0.5
	var h := size.y
	var hl := size.z * 0.5
	var v := [
		Vector3(-hw, 0.0, -hl),
		Vector3(hw, 0.0, -hl),
		Vector3(-hw, 0.0, hl),
		Vector3(hw, 0.0, hl),
		Vector3(-hw, h, -hl),
		Vector3(hw, h, -hl),
	]
	var faces := [
		[0, 1, 5, 0, 5, 4],
		[0, 2, 3, 0, 3, 1],
		[0, 4, 2],
		[1, 3, 5],
		[4, 5, 3, 4, 3, 2],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face:
			st.add_vertex(v[index])
	st.generate_normals()
	return st.commit()
