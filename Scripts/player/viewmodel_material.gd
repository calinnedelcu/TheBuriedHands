class_name ViewmodelMaterial
extends RefCounted
## Swaps the materials of a held visual for the depth-squashed viewmodel
## shader (keeping each surface's albedo), turns off shadow casting so the
## player's own arms never throw shadows across the room, and moves it to the
## viewmodel render layer (lit by the hand light, not by the lamp's world light).

const SHADER := preload("res://assets/shaders/viewmodel.gdshader")
const LAYER := 2

static var _cache: Dictionary = {}

static func apply(root: Node) -> void:
	var nodes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.append(root)
	for n in nodes:
		var g := n as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.layers = LAYER
		if not (g is MeshInstance3D) or (g as MeshInstance3D).mesh == null:
			continue
		var mi := g as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var source := mi.get_active_material(s)
			if source is ShaderMaterial:
				continue  # flames and other custom shaders keep their own look
			mi.set_surface_override_material(s, _converted(source))

static func _converted(source: Material) -> ShaderMaterial:
	if _cache.has(source):
		return _cache[source]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		mat.set_shader_parameter(&"albedo_color", base.albedo_color)
		mat.set_shader_parameter(&"use_texture", base.albedo_texture != null)
		if base.albedo_texture != null:
			mat.set_shader_parameter(&"albedo_texture", base.albedo_texture)
		mat.set_shader_parameter(&"roughness", base.roughness)
		mat.set_shader_parameter(&"metallic", base.metallic)
	_cache[source] = mat
	return mat
